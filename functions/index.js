/**
 * Cloud Functions para Minha Barbearia.
 * - onAppointmentCreated: push ao dono (novo agend.) e ao cliente (solicitação pendente de confirmação).
 * - onAppointmentUpdated: confirmação, remarcação, proposta de horário (proposedDateTime), cancelamento.
 * - clientRespondToAppointmentProposal: cliente aceita/recusa horário sugerido (HTTPS callable).
 * - onBarberProductCreated / onBarberProductUpdated: estoque ≤ mínimo; uso no studio ≤15%.
 * - sendAppointmentReminders: a cada 5 min — lembrete ~30 min antes (status pending ou confirmed).
 * - createCheckoutSession, syncSubscriptionFromCheckout: Stripe Checkout (us-central1).
 * - stripeWebhook: HTTP; raw body; secrets STRIPE_SECRET_KEY + STRIPE_WEBHOOK_SECRET.
 *
 * Pré-requisitos: plano Blaze. Deploy: firebase deploy --only functions
 */
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onCall, onRequest, HttpsError } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import express from 'express';
import Stripe from 'stripe';

const stripeSecretKey = defineSecret('STRIPE_SECRET_KEY');
const stripeWebhookSecret = defineSecret('STRIPE_WEBHOOK_SECRET');

initializeApp();

const firestore = getFirestore();
const messaging = getMessaging();
const authAdmin = getAuth();

/**
 * Quem pode abrir o painel admin (lista de negócios, etc.).
 * 1) Se o e-mail do token for o dono do produto (recomendado após recriar conta no Auth).
 * 2) Senão, se existir `adminUids` em app_config/config — inclui esse UID.
 * 3) Senão, fallback para UIDs legados em ADMIN_UID_LEGACY (conta recriada no Auth).
 */
/** E-mails com acesso ao painel admin quando o Auth devolve esse e-mail na conta (Google). */
const ADMIN_OWNER_EMAIL = 'fabianoeugenio96@gmail.com';
/** UIDs legados quando não há lista em Firestore — inclui conta recriada no Auth. */
const ADMIN_UID_LEGACY = [
  '7rNwYcg61hcGgg6IeCRBjSytyBq1',
  'JWiiOV3Q6aZ5vSQSJCybNFmP92H2',
];

async function isPlatformAdmin(uid) {
  let userRecord = null;
  try {
    userRecord = await authAdmin.getUser(uid);
  } catch (e) {
    console.warn('isPlatformAdmin getUser', uid, e?.message || e);
  }
  const email = userRecord?.email?.trim().toLowerCase();
  if (email && email === ADMIN_OWNER_EMAIL.toLowerCase()) {
    return true;
  }
  const configSnap = await firestore.collection('app_config').doc('config').get();
  const adminUids = configSnap?.data()?.adminUids;
  if (Array.isArray(adminUids) && adminUids.length > 0) {
    return adminUids.includes(uid);
  }
  return ADMIN_UID_LEGACY.includes(uid);
}

function formatDateTime(date) {
  return date.toLocaleDateString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function timestampMillis(t) {
  if (!t) return null;
  if (typeof t.toMillis === 'function') return t.toMillis();
  if (t._seconds !== undefined) return t._seconds * 1000;
  return null;
}

/** FCM exige que todos os valores de `data` sejam strings. */
function fcmStringData(data) {
  if (!data || typeof data !== 'object') return {};
  const o = {};
  for (const [k, v] of Object.entries(data)) {
    o[k] = v == null ? '' : String(v);
  }
  return o;
}

async function sendPushToTokens(tokens, title, body, data) {
  const list = (tokens || []).filter(Boolean);
  if (list.length === 0) return;
  try {
    await messaging.sendEachForMulticast({
      tokens: list,
      notification: { title, body },
      data: fcmStringData(data),
    });
  } catch (e) {
    console.warn('FCM sendPushToTokens:', e.message);
  }
}

async function loadOwnerTokens(slug) {
  const shopSnap = await firestore.collection('barbershops').doc(slug).get();
  return shopSnap?.data()?.ownerFcmTokens || [];
}

async function loadClientTokensByWhatsapp(slug, whatsapp) {
  const w = (whatsapp || '').toString().replace(/\D/g, '');
  if (!w || w.length < 10) return [];
  try {
    const snap = await firestore
      .collection('barbershops')
      .doc(slug)
      .collection('clients')
      .where('whatsapp', '==', w)
      .limit(1)
      .get();
    if (snap.empty) return [];
    return snap.docs[0].data()?.fcmTokens || [];
  } catch (e) {
    console.warn('loadClientTokensByWhatsapp', e.message);
    return [];
  }
}

/** Tokens FCM do cliente: documento por clientId; se vazio, tenta casar WhatsApp do agendamento. */
async function loadClientTokens(slug, clientId, clientWhatsapp) {
  let tokens = [];
  if (clientId) {
    try {
      const clientSnap = await firestore
        .collection('barbershops')
        .doc(slug)
        .collection('clients')
        .doc(clientId)
        .get();
      tokens = clientSnap?.data()?.fcmTokens || [];
    } catch (e) {
      console.warn('loadClientTokens', e.message);
    }
  }
  if (tokens.length === 0 && clientWhatsapp) {
    tokens = await loadClientTokensByWhatsapp(slug, clientWhatsapp);
  }
  return tokens;
}

/**
 * Novo agendamento criado → push para dono (ownerFcmTokens) e cliente (fcmTokens). Usa sendMulticast para arrays.
 */
export const onAppointmentCreated = onDocumentCreated(
  { document: 'appointments/{appointmentId}', region: 'us-central1' },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    const slug = data.barberShopId;
    const clientId = data.clientId;
    const clientName = data.clientName || 'Cliente';
    const serviceName = data.serviceName || 'Serviço';
    const dateTime = data.dateTime?.toDate?.() || new Date();
    const dateStr = formatDateTime(dateTime);

    const sendPromises = [];

    // Dono: barbershops/{slug}.ownerFcmTokens (array)
    try {
      const shopSnap = await firestore.collection('barbershops').doc(slug).get();
      const ownerTokens = shopSnap?.data()?.ownerFcmTokens || [];
      if (ownerTokens.length > 0) {
        sendPromises.push(
          messaging.sendEachForMulticast({
            tokens: ownerTokens,
            notification: {
              title: 'Novo agendamento na sua barbearia',
              body: `${clientName} – ${serviceName} em ${dateStr}`,
            },
            data: fcmStringData({
              type: 'appointment_created',
              appointmentId: event.params.appointmentId,
              barberShopId: slug,
            }),
          })
        );
      }
    } catch (e) {
      console.warn('Owner FCM send failed:', e.message);
    }

    // Cliente: barbershops/{slug}/clients/{clientId}.fcmTokens (array)
    if (clientId) {
      try {
        const clientSnap = await firestore
          .collection('barbershops')
          .doc(slug)
          .collection('clients')
          .doc(clientId)
          .get();
        const clientTokens = clientSnap?.data()?.fcmTokens || [];
        const tokens = clientTokens.length
          ? clientTokens
          : await loadClientTokensByWhatsapp(slug, data.clientWhatsapp);
        if (tokens.length > 0) {
          sendPromises.push(
            messaging.sendEachForMulticast({
              tokens,
              notification: {
                title: 'Solicitação de agendamento',
                body: `${serviceName} em ${dateStr}. Aguardando confirmação do estabelecimento.`,
              },
              data: fcmStringData({
                type: 'appointment_created',
                appointmentId: event.params.appointmentId,
                barberShopId: slug,
              }),
            })
          );
        }
      } catch (e) {
        console.warn('Client FCM send failed:', e.message);
      }
    } else if (data.clientWhatsapp) {
      try {
        const tokens = await loadClientTokensByWhatsapp(slug, data.clientWhatsapp);
        if (tokens.length > 0) {
          sendPromises.push(
            messaging.sendEachForMulticast({
              tokens,
              notification: {
                title: 'Solicitação de agendamento',
                body: `${serviceName} em ${dateStr}. Aguardando confirmação do estabelecimento.`,
              },
              data: fcmStringData({
                type: 'appointment_created',
                appointmentId: event.params.appointmentId,
                barberShopId: slug,
              }),
            })
          );
        }
      } catch (e) {
        console.warn('Client FCM (whatsapp) send failed:', e.message);
      }
    }

    await Promise.allSettled(sendPromises);
  }
);

/**
 * Agendamento alterado: confirmação, remarcação (data/hora), cancelamento.
 */
export const onAppointmentUpdated = onDocumentUpdated(
  { document: 'appointments/{appointmentId}', region: 'us-central1' },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    const slug = after.barberShopId;
    const clientId = after.clientId;
    if (!slug) return;

    const apptId = event.params.appointmentId;
    const dataBase = { appointmentId: apptId, barberShopId: slug, type: 'appointment_updated' };

    const sBefore = before.status;
    const sAfter = after.status;
    const tBefore = timestampMillis(before.dateTime);
    const tAfter = timestampMillis(after.dateTime);
    const dateTimeChanged = tBefore != null && tAfter != null && tBefore !== tAfter;
    const statusChanged = sBefore !== sAfter;

    const serviceName = after.serviceName || 'Serviço';
    const dateTime = after.dateTime?.toDate?.() || new Date();
    const dateStr = formatDateTime(dateTime);
    const clientName = after.clientName || 'Cliente';
    const canceledBy = after.canceledBy;

    const propBeforeMs = timestampMillis(before.proposedDateTime);
    const propAfterMs = timestampMillis(after.proposedDateTime);
    const proposalAdded = propAfterMs != null && propBeforeMs == null;
    const proposalRemoved = propBeforeMs != null && propAfterMs == null;

    const ownerTokens = await loadOwnerTokens(slug);
    const clientTokens = await loadClientTokens(slug, clientId, after.clientWhatsapp);

    if (statusChanged && sAfter === 'canceled') {
      if (canceledBy === 'client') {
        await sendPushToTokens(
          ownerTokens,
          'Agendamento cancelado pelo cliente',
          `${clientName} cancelou: ${serviceName} (${dateStr}).`,
          { ...dataBase, subType: 'canceled_by_client' }
        );
        await sendPushToTokens(
          clientTokens,
          'Agendamento cancelado',
          `Seu horário de ${serviceName} em ${dateStr} foi cancelado.`,
          { ...dataBase, subType: 'canceled' }
        );
      } else if (canceledBy === 'owner') {
        await sendPushToTokens(
          clientTokens,
          'Agendamento cancelado',
          `O estabelecimento cancelou seu horário: ${serviceName} (${dateStr}).`,
          { ...dataBase, subType: 'canceled_by_owner' }
        );
      } else {
        await sendPushToTokens(
          ownerTokens,
          'Agendamento cancelado',
          `${serviceName} — ${dateStr} foi cancelado.`,
          { ...dataBase, subType: 'canceled' }
        );
        await sendPushToTokens(
          clientTokens,
          'Agendamento cancelado',
          `O horário de ${serviceName} em ${dateStr} foi cancelado.`,
          { ...dataBase, subType: 'canceled' }
        );
      }
      return;
    }

    if (proposalAdded && sAfter !== 'canceled') {
      const proposedDt = after.proposedDateTime?.toDate?.() || new Date();
      const proposedStr = formatDateTime(proposedDt);
      await sendPushToTokens(
        clientTokens,
        'Novo horário sugerido',
        `O estabelecimento propõe ${serviceName} para ${proposedStr}. Abra o app para confirmar ou recusar.`,
        { ...dataBase, subType: 'proposal_created' }
      );
    }

    // Pendente → confirmado no mesmo update que muda data/hora: envia só a confirmação
    // (a mensagem já inclui o horário final). Não reutilizar o ramo "remarcado" com return
    // antecipado, senão o cliente nunca recebia o push de confirmação.
    const isConfirm = statusChanged && sBefore === 'pending' && sAfter === 'confirmed';

    if (dateTimeChanged && sAfter !== 'canceled' && sBefore !== 'canceled' && !isConfirm) {
      const clientAcceptedProposal =
        proposalRemoved && propBeforeMs != null && tAfter === propBeforeMs;

      if (clientAcceptedProposal) {
        await sendPushToTokens(
          ownerTokens,
          'Cliente aceitou o horário sugerido',
          `${clientName} — ${serviceName} confirmado para ${dateStr}.`,
          { ...dataBase, subType: 'proposal_accepted' }
        );
        await sendPushToTokens(
          clientTokens,
          'Horário atualizado',
          `${serviceName} em ${dateStr}.`,
          { ...dataBase, subType: 'proposal_accepted' }
        );
      } else {
        await sendPushToTokens(
          ownerTokens,
          'Horário remarcado',
          `${clientName} — ${serviceName} agora em ${dateStr}.`,
          { ...dataBase, subType: 'rescheduled' }
        );
        await sendPushToTokens(
          clientTokens,
          'Horário remarcado',
          `${serviceName} atualizado para ${dateStr}.`,
          { ...dataBase, subType: 'rescheduled' }
        );
      }
    }

    if (isConfirm) {
      await sendPushToTokens(
        clientTokens,
        'Horário confirmado',
        `O barbeiro confirmou: ${serviceName} em ${dateStr}.`,
        { ...dataBase, subType: 'confirmed' }
      );
    }
  }
);

/**
 * Estoque: novo produto já abaixo do mínimo (ou studio baixo) na criação.
 */
export const onBarberProductCreated = onDocumentCreated(
  { document: 'barbershops/{slug}/products/{productId}', region: 'us-central1' },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const after = snap.data();
    if (!after) return;
    const slug = event.params.slug;
    const productName = after.name || 'Produto';
    const minA = (after.minStock != null ? Number(after.minStock) : 0) || 0;
    const curA = (after.currentStock != null ? Number(after.currentStock) : 0) || 0;
    if (minA > 0 && curA <= minA) {
      const ownerTokens = await loadOwnerTokens(slug);
      await sendPushToTokens(
        ownerTokens,
        'Estoque em alerta',
        `${productName}: estoque inicial ${curA} (mínimo ${minA}).`,
        { type: 'stock_low', barberShopId: slug, productId: event.params.productId }
      );
    }
    const aS = after.studioRemainingPercent != null ? Number(after.studioRemainingPercent) : null;
    if (aS != null && aS > 0 && aS <= 15) {
      const ownerTokens = await loadOwnerTokens(slug);
      await sendPushToTokens(
        ownerTokens,
        'Produto no studio quase a acabar',
        `${productName} — use no studio: ~${aS}% restante.`,
        { type: 'stock_studio_low', barberShopId: slug, productId: event.params.productId }
      );
    }
  }
);

/**
 * Estoque: aviso ao dono quando cruza o mínimo ou produto do studio cai a ≤15%.
 */
export const onBarberProductUpdated = onDocumentUpdated(
  { document: 'barbershops/{slug}/products/{productId}', region: 'us-central1' },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    const slug = event.params.slug;
    const productName = after.name || 'Produto';
    const minA = (after.minStock != null ? Number(after.minStock) : 0) || 0;
    const curA = (after.currentStock != null ? Number(after.currentStock) : 0) || 0;
    const curB = (before.currentStock != null ? Number(before.currentStock) : 0) || 0;

    const wasBelowOrEqualMin = minA > 0 && curB <= minA;
    const isBelowOrEqualMin = minA > 0 && curA <= minA;
    if (!wasBelowOrEqualMin && isBelowOrEqualMin) {
      const ownerTokens = await loadOwnerTokens(slug);
      await sendPushToTokens(
        ownerTokens,
        'Estoque em alerta',
        `${productName}: estoque em ${curA} (mínimo ${minA}). Repor?`,
        { type: 'stock_low', barberShopId: slug, productId: event.params.productId }
      );
    }

    const bS = before.studioRemainingPercent != null ? Number(before.studioRemainingPercent) : null;
    const aS = after.studioRemainingPercent != null ? Number(after.studioRemainingPercent) : null;
    if (aS != null && aS > 0 && aS <= 15) {
      const crossed = bS == null || bS > 15;
      if (crossed) {
        const ownerTokens = await loadOwnerTokens(slug);
        await sendPushToTokens(
          ownerTokens,
          'Produto no studio quase a acabar',
          `${productName} — use em stock no studio: ~${aS}%. Guarde o restante de uso.`,
          { type: 'stock_studio_low', barberShopId: slug, productId: event.params.productId }
        );
      }
    }
  }
);

/**
 * A cada 5 minutos: busca agendamentos entre now+25min e now+35min com reminderSent != true,
 * envia lembrete para o cliente (fcmTokens) e marca reminderSent = true.
 */
export const sendAppointmentReminders = onSchedule(
  { schedule: 'every 5 minutes', timeZone: 'America/Sao_Paulo' },
  async () => {
    const now = new Date();
    const windowStart = new Date(now.getTime() + 25 * 60 * 1000);
    const windowEnd = new Date(now.getTime() + 35 * 60 * 1000);

    const snap = await firestore
      .collection('appointments')
      .where('dateTime', '>=', windowStart)
      .where('dateTime', '<=', windowEnd)
      .get();

    for (const doc of snap.docs) {
      const data = doc.data();
      if (data.reminderSent === true) continue;
      const st = data.status;
      if (st !== 'pending' && st !== 'confirmed') continue;

      const slug = data.barberShopId;
      const clientId = data.clientId;
      const serviceName = data.serviceName || 'Serviço';
      const dateTime = data.dateTime?.toDate?.() || new Date();
      const dateStr = formatDateTime(dateTime);

      if (!slug) continue;

      try {
        let clientTokens = [];
        if (clientId) {
          const clientSnap = await firestore
            .collection('barbershops')
            .doc(slug)
            .collection('clients')
            .doc(clientId)
            .get();
          clientTokens = clientSnap?.data()?.fcmTokens || [];
        }
        if (clientTokens.length === 0) {
          clientTokens = await loadClientTokens(slug, clientId || '', data.clientWhatsapp);
        }
        if (clientTokens.length === 0) {
          await doc.ref.update({ reminderSent: true });
          continue;
        }

        await messaging.sendEachForMulticast({
          tokens: clientTokens,
          notification: {
            title: 'Lembrete: seu horário é em breve',
            body: `${serviceName} em ${dateStr}. Te esperamos!`,
          },
          data: fcmStringData({
            type: 'appointment_reminder',
            appointmentId: doc.id,
            barberShopId: slug,
          }),
        });

        await doc.ref.update({
          reminderSent: true,
          reminderSentAt: new Date(),
        });
      } catch (e) {
        console.warn('Reminder send failed for', doc.id, e.message);
      }
    }
  }
);

function normalizeClientPhone(value) {
  return (value ?? '').toString().replace(/\D/g, '');
}

/**
 * Cliente autenticado aceita ou recusa horário sugerido pelo dono (proposedDateTime).
 */
export const clientRespondToAppointmentProposal = onCall(
  { region: 'us-central1' },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Faça login para responder.');
      }
      const uid = request.auth.uid;
      const appointmentId = request.data?.appointmentId;
      const accept = request.data?.accept === true;
      if (!appointmentId || typeof appointmentId !== 'string') {
        throw new HttpsError('invalid-argument', 'appointmentId inválido.');
      }

      const apptRef = firestore.collection('appointments').doc(appointmentId);
      const apptSnap = await apptRef.get();
      if (!apptSnap.exists) {
        throw new HttpsError('not-found', 'Agendamento não encontrado.');
      }
      const appt = apptSnap.data();
      const slug = appt.barberShopId;
      const clientId = appt.clientId;
      if (!slug || !clientId) {
        throw new HttpsError('failed-precondition', 'Agendamento sem barbearia ou cliente.');
      }

      const appointmentClientRef = firestore
        .collection('barbershops')
        .doc(slug)
        .collection('clients')
        .doc(clientId);
      const appointmentClientSnap = await appointmentClientRef.get();
      if (!appointmentClientSnap.exists) {
        throw new HttpsError('not-found', 'Cliente não encontrado.');
      }

      const apptCd = appointmentClientSnap.data();
      const apptWhatsapp = normalizeClientPhone(appt.clientWhatsapp);

      let authorized = apptCd?.authUid === uid;
      if (!authorized && apptWhatsapp.length >= 10) {
        const byAuthSnap = await firestore
          .collection('barbershops')
          .doc(slug)
          .collection('clients')
          .where('authUid', '==', uid)
          .limit(10)
          .get();
        for (const doc of byAuthSnap.docs) {
          if (normalizeClientPhone(doc.data()?.whatsapp) === apptWhatsapp) {
            authorized = true;
            break;
          }
        }
      }

      if (!authorized) {
        throw new HttpsError(
          'permission-denied',
          'Esta conta não pode responder por este agendamento.'
        );
      }

      const proposed = appt.proposedDateTime;
      if (!proposed) {
        throw new HttpsError('failed-precondition', 'Não há horário sugerido para responder.');
      }

      const serviceName = appt.serviceName || 'Serviço';
      const clientName = appt.clientName || 'Cliente';
      const prevDate = appt.dateTime?.toDate?.() || new Date();
      const prevStr = formatDateTime(prevDate);

      if (accept) {
        await apptRef.update({
          dateTime: proposed,
          proposedDateTime: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      } else {
        await apptRef.update({
          proposedDateTime: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        const ownerTokens = await loadOwnerTokens(slug);
        await sendPushToTokens(
          ownerTokens,
          'Cliente recusou o horário sugerido',
          `${clientName} manteve ${serviceName} em ${prevStr}.`,
          {
            type: 'appointment_updated',
            appointmentId,
            barberShopId: slug,
            subType: 'proposal_declined',
          }
        );
      }

      return { ok: true };
    } catch (e) {
      if (e instanceof HttpsError) {
        throw e;
      }
      console.error('clientRespondToAppointmentProposal', e);
      throw new HttpsError(
        'internal',
        e?.message ? String(e.message) : 'Falha ao processar resposta.'
      );
    }
  }
);

/**
 * Painel admin: dono por e-mail (Firebase Auth) ou UID em app_config/config.adminUids.
 */
export const getAdminDashboard = onCall(
  { region: 'us-central1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Faça login para acessar.');
    }
    const uid = request.auth.uid;
    if (!(await isPlatformAdmin(uid))) {
      return { isAdmin: false };
    }
    const shopsSnap = await firestore.collection('barbershops').get();
    const barberShops = shopsSnap.docs
      .map((doc) => {
      const d = doc.data();
      const createdAt = d.createdAt?.toDate?.();
      const trialEndsAt = d.trialEndsAt?.toDate?.();
      return {
        id: doc.id,
        name: d.name || '',
        slug: d.slug || doc.id,
        ownerUid: d.ownerUid || null,
        plan: d.plan || 'basic',
        subscriptionStatus: d.subscriptionStatus || 'trial',
        createdAt: createdAt ? createdAt.toISOString() : null,
        trialEndsAt: trialEndsAt ? trialEndsAt.toISOString() : null,
      };
    })
      .sort((a, b) => {
        const ta = a.createdAt ? new Date(a.createdAt).getTime() : 0;
        const tb = b.createdAt ? new Date(b.createdAt).getTime() : 0;
        return tb - ta;
      });
    return { isAdmin: true, barberShops };
  }
);

/**
 * Sincroniza o Firestore após o Checkout (cliente chama com session_id vindo do success_url).
 */
export const syncSubscriptionFromCheckout = onCall(
  { region: 'us-central1', secrets: [stripeSecretKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Faça login para continuar.');
    }
    const sessionId = request.data?.sessionId;
    if (!sessionId || typeof sessionId !== 'string') {
      throw new HttpsError('invalid-argument', 'Envie sessionId (id da sessão de checkout).');
    }
    const stripe = new Stripe(stripeSecretKey.value());
    const session = await stripe.checkout.sessions.retrieve(sessionId, {
      expand: ['subscription', 'customer'],
    });
    if (session.status !== 'complete') {
      throw new HttpsError('failed-precondition', 'A sessão de checkout ainda não foi concluída.');
    }
    if (session.mode !== 'subscription') {
      throw new HttpsError('failed-precondition', 'Essa sessão não é de assinatura.');
    }
    if (session.payment_status !== 'paid' && session.payment_status !== 'no_payment_required') {
      throw new HttpsError('failed-precondition', 'Pagamento ainda não confirmado.');
    }
    const slug = session.client_reference_id || session.metadata?.slug;
    if (!slug) {
      throw new HttpsError('failed-precondition', 'Sessão sem identificador do negócio.');
    }
    const shopRef = firestore.collection('barbershops').doc(slug);
    const shopSnap = await shopRef.get();
    if (!shopSnap.exists) {
      throw new HttpsError('not-found', 'Negócio não encontrado.');
    }
    if (shopSnap.data().ownerUid !== request.auth.uid) {
      throw new HttpsError('permission-denied', 'Apenas o dono pode ativar a assinatura deste negócio.');
    }
    const subRef = session.subscription;
    const customerRef = session.customer;
    const subscriptionId = typeof subRef === 'string' ? subRef : subRef?.id;
    const customerId = typeof customerRef === 'string' ? customerRef : customerRef?.id;
    if (!subscriptionId || !customerId) {
      throw new HttpsError('internal', 'Dados de assinatura incompletos no Stripe.');
    }
    await applyPaidSubscriptionToShopWithStripe(stripe, slug, customerId, subscriptionId);
    return { success: true };
  }
);

/**
 * Cancela a renovação no fim do período pago (continua a usar até current_period_end).
 */
export const cancelSubscriptionAtPeriodEnd = onCall(
  { region: 'us-central1', secrets: [stripeSecretKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Faça login.');
    }
    const slug = request.data?.slug;
    if (!slug) {
      throw new HttpsError('invalid-argument', 'Envie slug.');
    }
    const shop = await firestore.collection('barbershops').doc(slug).get();
    if (!shop.exists) throw new HttpsError('not-found', 'Negócio não encontrado.');
    if (shop.data().ownerUid !== request.auth.uid) {
      throw new HttpsError('permission-denied', 'Apenas o dono.');
    }
    const subId = shop.data().stripeSubscriptionId;
    if (!subId) {
      throw new HttpsError('failed-precondition', 'Sem assinatura Stripe ativa.');
    }
    const stripe = new Stripe(stripeSecretKey.value());
    await stripe.subscriptions.update(subId, { cancel_at_period_end: true });
    const sub = await stripe.subscriptions.retrieve(subId);
    await writeSubscriptionToFirestoreFromStripeObject(slug, sub);
    return { success: true, cancelAtPeriodEnd: true };
  }
);

/**
 * Reembolsa só a fatura paga do período atual (última paga) e revoga acesso.
 */
export const refundCurrentPeriodSubscription = onCall(
  { region: 'us-central1', secrets: [stripeSecretKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Faça login.');
    }
    const slug = request.data?.slug;
    if (!slug) {
      throw new HttpsError('invalid-argument', 'Envie slug.');
    }
    const shop = await firestore.collection('barbershops').doc(slug).get();
    if (!shop.exists) throw new HttpsError('not-found', 'Negócio não encontrado.');
    if (shop.data().ownerUid !== request.auth.uid) {
      throw new HttpsError('permission-denied', 'Apenas o dono.');
    }
    const subId = shop.data().stripeSubscriptionId;
    if (!subId) {
      throw new HttpsError('failed-precondition', 'Sem assinatura ativa para reembolsar.');
    }
    const stripe = new Stripe(stripeSecretKey.value());
    const sub = await stripe.subscriptions.retrieve(subId);
    const inv = await stripe.invoices.list({ subscription: subId, status: 'paid', limit: 1 });
    if (!inv.data.length) {
      throw new HttpsError('failed-precondition', 'Nenhuma fatura paga encontrada.');
    }
    const lastInv = inv.data[0];
    const chargeId = lastInv.charge
      ? typeof lastInv.charge === 'string'
        ? lastInv.charge
        : lastInv.charge.id
      : null;
    if (!chargeId) {
      throw new HttpsError('failed-precondition', 'Cobrança da fatura não disponível para reembolso.');
    }
    const re = await stripe.refunds.create({ charge: chargeId });
    try {
      await stripe.subscriptions.cancel(subId);
    } catch (e) {
      console.warn('Cancel sub após reembolso', e?.message);
    }
    await firestore
      .collection('barbershops')
      .doc(slug)
      .set(
        {
          subscriptionStatus: 'refunded',
          plan: 'basic',
          cancelAtPeriodEnd: false,
          subscriptionCurrentPeriodEnd: null,
          stripeSubscriptionId: null,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    await appendBillingEvent(slug, {
      id: re.id,
      type: 'refund',
      amount: -(
        re.amount
      ),
      currency: re.currency,
      description: 'Reembolso — mês pago (período atual)',
    });
    return { success: true, refundId: re.id };
  }
);

/**
 * Cria uma sessão do Stripe Checkout para assinatura ou pagamento único.
 * Parâmetros: slug, priceId ou productId, mode ('subscription' | 'payment'), successUrl, cancelUrl.
 * Se enviar productId (prod_...), o preço padrão do produto é usado.
 */
export const createCheckoutSession = onCall(
  { region: 'us-central1', secrets: [stripeSecretKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Faça login para continuar.');
    }
    const { slug, priceId, productId, mode, successUrl, cancelUrl } = request.data || {};
    if (!slug || (!priceId && !productId) || !mode || !successUrl || !cancelUrl) {
      throw new HttpsError('invalid-argument', 'Envie slug, priceId ou productId, mode, successUrl e cancelUrl.');
    }
    if (mode !== 'subscription' && mode !== 'payment') {
      throw new HttpsError('invalid-argument', 'mode deve ser "subscription" ou "payment".');
    }

    const uid = request.auth.uid;
    const shopSnap = await firestore.collection('barbershops').doc(slug).get();
    if (!shopSnap.exists) {
      throw new HttpsError('not-found', 'Negócio não encontrado.');
    }
    const shopData = shopSnap.data();
    if (shopData.ownerUid !== uid) {
      throw new HttpsError('permission-denied', 'Só o dono pode assinar.');
    }

    const stripe = new Stripe(stripeSecretKey.value());
    let resolvedPriceId = priceId;
    if (!resolvedPriceId && productId) {
      const product = await stripe.products.retrieve(productId);
      const defaultPrice = product.default_price;
      resolvedPriceId = typeof defaultPrice === 'string' ? defaultPrice : defaultPrice?.id;
      if (!resolvedPriceId) {
        throw new HttpsError('failed-precondition', 'Produto sem preço padrão. Defina um preço no Stripe.');
      }
    }

    const customerId = shopData.stripeCustomerId || null;
    const customerEmail = request.auth.token?.email || null;

    const sessionConfig = {
      mode,
      line_items: [{ price: resolvedPriceId, quantity: 1 }],
      success_url: successUrl,
      cancel_url: cancelUrl,
      client_reference_id: slug,
      metadata: { slug },
      locale: 'pt-BR',
      allow_promotion_codes: true,
    };
    if (mode === 'subscription') {
      sessionConfig.subscription_data = { metadata: { slug } };
    }
    if (customerId) {
      sessionConfig.customer = customerId;
    } else if (customerEmail) {
      sessionConfig.customer_email = customerEmail;
    }

    const session = await stripe.checkout.sessions.create(sessionConfig);
    return { url: session.url };
  }
);

// --- Webhook Stripe (HTTP + corpo bruto) ---

const app = express();

/**
 * Mapeia status do Stripe (Subscription) para subscriptionStatus do app.
 */
function mapSubscriptionStatusToApp(stripeStatus) {
  if (stripeStatus === 'active' || stripeStatus === 'trialing') return 'active';
  if (stripeStatus === 'canceled' || stripeStatus === 'incomplete_expired') return 'canceled';
  if (['past_due', 'unpaid', 'incomplete', 'paused'].includes(stripeStatus)) return 'past_due';
  return 'trial';
}

function tsFromStripeSec(sec) {
  if (!sec) return null;
  return Timestamp.fromDate(new Date(sec * 1000));
}

/**
 * Sincroniza o documento do negócio a partir de um objeto Subscription do Stripe.
 */
async function writeSubscriptionToFirestoreFromStripeObject(slug, sub) {
  const customerId = typeof sub.customer === 'string' ? sub.customer : sub.customer?.id;
  const st = mapSubscriptionStatusToApp(sub.status);
  const plan = st === 'active' || st === 'past_due' ? 'pro' : 'basic';
  await firestore
    .collection('barbershops')
    .doc(slug)
    .set(
      {
        stripeCustomerId: customerId,
        stripeSubscriptionId: sub.id,
        subscriptionStatus: st,
        cancelAtPeriodEnd: !!sub.cancel_at_period_end,
        subscriptionCurrentPeriodEnd: tsFromStripeSec(sub.current_period_end),
        plan,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
}

async function applyPaidSubscriptionToShopWithStripe(stripe, slug, customerId, subscriptionId) {
  const sub = await stripe.subscriptions.retrieve(subscriptionId);
  await writeSubscriptionToFirestoreFromStripeObject(slug, sub);
}

async function appendBillingEvent(slug, { id, type, amount, currency, description, extra }) {
  if (!id) return;
  const payload = {
    type,
    amount,
    currency: (currency || 'brl').toString().toLowerCase(),
    description: description || '',
    createdAt: FieldValue.serverTimestamp(),
  };
  if (extra && typeof extra === 'object') {
    Object.assign(payload, extra);
  }
  await firestore
    .collection('barbershops')
    .doc(slug)
    .collection('billingEvents')
    .doc(String(id))
    .set(payload, { merge: true });
}

async function findSlugBySubscriptionId(stripe, subscriptionId) {
  if (!subscriptionId) return null;
  const direct = await firestore
    .collection('barbershops')
    .where('stripeSubscriptionId', '==', subscriptionId)
    .limit(1)
    .get();
  if (!direct.empty) return direct.docs[0].id;
  const sub = await stripe.subscriptions.retrieve(subscriptionId);
  if (sub.metadata?.slug) return sub.metadata.slug;
  return null;
}

async function findSlugByCustomerId(customerId) {
  if (!customerId) return null;
  const direct = await firestore
    .collection('barbershops')
    .where('stripeCustomerId', '==', customerId)
    .limit(1)
    .get();
  if (!direct.empty) return direct.docs[0].id;
  return null;
}

app.post(
  '/',
  express.raw({ type: 'application/json' }),
  async (req, res) => {
    const stripe = new Stripe(stripeSecretKey.value());
    const sig = req.headers['stripe-signature'];
    let event;
    try {
      event = stripe.webhooks.constructEvent(req.body, sig, stripeWebhookSecret.value());
    } catch (err) {
      console.error('Webhook signature:', err.message);
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    try {
      if (event.type === 'checkout.session.completed') {
        const session = event.data.object;
        if (session.mode === 'subscription' && session.status === 'complete') {
          const slug = session.client_reference_id || session.metadata?.slug;
          const subRef = session.subscription;
          const customerRef = session.customer;
          const subscriptionId = typeof subRef === 'string' ? subRef : subRef?.id;
          const customerId = typeof customerRef === 'string' ? customerRef : customerRef?.id;
          if (slug && subscriptionId && customerId) {
            await applyPaidSubscriptionToShopWithStripe(stripe, slug, customerId, subscriptionId);
          }
        }
      } else if (event.type === 'customer.subscription.updated' || event.type === 'customer.subscription.deleted') {
        const sub = event.data.object;
        const subId = sub.id;
        let slug = sub.metadata?.slug;
        if (!slug) {
          slug = await findSlugBySubscriptionId(stripe, subId);
        }
        if (!slug) {
          const customerId = typeof sub.customer === 'string' ? sub.customer : sub.customer?.id;
          if (customerId) {
            slug = await findSlugByCustomerId(customerId);
          }
        }
        if (slug) {
          await writeSubscriptionToFirestoreFromStripeObject(slug, sub);
        } else {
          console.warn('Webhook: assinatura sem barbershop mapeado', subId);
        }
      } else if (event.type === 'invoice.paid' || event.type === 'invoice.payment_succeeded') {
        const inv = event.data.object;
        const subId = typeof inv.subscription === 'string' ? inv.subscription : inv.subscription?.id;
        if (subId) {
          const slug = await findSlugBySubscriptionId(stripe, subId);
          if (slug) {
            const sub = await stripe.subscriptions.retrieve(subId);
            await writeSubscriptionToFirestoreFromStripeObject(slug, sub);
            if (inv.amount_paid > 0) {
              let discountCents = 0;
              if (Array.isArray(inv.total_discount_amounts) && inv.total_discount_amounts.length) {
                discountCents = inv.total_discount_amounts.reduce((s, x) => s + (x?.amount || 0), 0);
              } else if (typeof inv.subtotal === 'number' && typeof inv.total === 'number') {
                discountCents = Math.max(0, (inv.subtotal || 0) - (inv.total || 0));
              }
              const num = inv.number || inv.id;
              await appendBillingEvent(slug, {
                id: inv.id,
                type: 'payment',
                amount: inv.amount_paid,
                currency: inv.currency,
                description: `Assinatura app — fatura ${num}`,
                extra: {
                  invoiceNumber: num,
                  subtotalCents: typeof inv.subtotal === 'number' ? inv.subtotal : null,
                  totalCents: typeof inv.total === 'number' ? inv.total : null,
                  discountCents,
                  hasPromotion: discountCents > 0,
                },
              });
            }
          }
        }
      } else if (event.type === 'refund.created') {
        const ref = event.data.object;
        const chId = typeof ref.charge === 'string' ? ref.charge : ref.charge?.id;
        if (chId) {
          const ch = await stripe.charges.retrieve(chId);
          const customerId = typeof ch.customer === 'string' ? ch.customer : ch.customer?.id;
          if (customerId) {
            const slug = await findSlugByCustomerId(customerId);
            if (slug) {
              await appendBillingEvent(slug, {
                id: ref.id,
                type: 'refund',
                amount: -ref.amount,
                currency: ref.currency,
                description: 'Reembolso (Stripe)',
              });
            }
          }
        }
      } else if (event.type === 'invoice.payment_failed') {
        const inv = event.data.object;
        const subId = typeof inv.subscription === 'string' ? inv.subscription : inv.subscription?.id;
        if (subId) {
          const slug = await findSlugBySubscriptionId(stripe, subId);
          if (slug) {
            await firestore.collection('barbershops').doc(slug).set(
              { subscriptionStatus: 'past_due', updatedAt: FieldValue.serverTimestamp() },
              { merge: true }
            );
          }
        }
      }
    } catch (e) {
      console.error('Webhook handler', e);
      return res.status(500).json({ error: e.message || 'erro' });
    }

    return res.json({ received: true });
  }
);

// invoker: 'public' = Stripe consegue enviar POST sem autenticação (validação = assinatura whsec_).
export const stripeWebhook = onRequest(
  {
    region: 'us-central1',
    secrets: [stripeSecretKey, stripeWebhookSecret],
    invoker: 'public',
  },
  app
);
