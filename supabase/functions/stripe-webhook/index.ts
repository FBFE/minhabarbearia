/**
 * Webhook Stripe (Supabase Edge, Deno).
 * Valida a assinatura com STRIPE_WEBHOOK_SECRET e atualiza Firestore (mesma base do app Flutter).
 *
 * Segredos no Supabase (Settings → Edge Functions → Secrets):
 *   STRIPE_WEBHOOK_SECRET   — whsec_... (este endpoint, no painel do Stripe)
 *   STRIPE_SECRET_KEY       — sk_live_... ou sk_test_... (só se precisar do fallback via API Stripe)
 *   GOOGLE_SERVICE_ACCOUNT  — JSON inteiro (uma linha) da conta de serviço com permissão no Firestore
 *   FIREBASE_PROJECT_ID     — ex.: flow-studio-10
 */
import { GoogleAuth } from "npm:google-auth-library@9.14.2";
// Supabase bundler: npm: é suportado
import Stripe from "npm:stripe@17.3.0";

const PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
const WEBHOOK_SECRET = Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "";
const STRIPE_KEY = Deno.env.get("STRIPE_SECRET_KEY") ?? "";
const SA_JSON = Deno.env.get("GOOGLE_SERVICE_ACCOUNT") ?? "";

function mapSubscriptionStatusToApp(
  s: string,
): "active" | "canceled" | "past_due" | "trial" {
  if (s === "active" || s === "trialing") return "active";
  if (s === "canceled" || s === "incomplete_expired") return "canceled";
  if (["past_due", "unpaid", "incomplete", "paused"].includes(s)) {
    return "past_due";
  }
  return "trial";
}

function strValue(s: string) {
  return { stringValue: s };
}
function tsValue() {
  return { timestampValue: new Date().toISOString() };
}

async function getAccessToken(): Promise<string> {
  const auth = new GoogleAuth({
    credentials: JSON.parse(SA_JSON),
    scopes: ["https://www.googleapis.com/auth/datastore"],
  });
  const client = await auth.getClient();
  const t = await client.getAccessToken();
  const tok = typeof t === "string" ? t : t?.token;
  if (!tok) throw new Error("Falha ao obter access_token do Firestore");
  return tok;
}

async function firestoreRunQuery(
  accessToken: string,
  fieldPath: string,
  value: string,
): Promise<string | null> {
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents:runQuery`;
  const body = {
    structuredQuery: {
      from: [{ collectionId: "barbershops" }],
      where: {
        fieldFilter: {
          field: { fieldPath },
          op: "EQUAL",
          value: { stringValue: value },
        },
      },
      limit: 1,
    },
  };
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    console.error("runQuery", res.status, await res.text());
    return null;
  }
  const data = (await res.json()) as Array<{ document?: { name: string } }>;
  for (const row of data) {
    const name = row.document?.name;
    if (name) {
      const match = /documents\/barbershops\/([^/]+)/.exec(name);
      if (match) return match[1]!;
    }
  }
  return null;
}

async function firestorePatchBarbershop(
  accessToken: string,
  slug: string,
  fields: Record<string, unknown>,
) {
  const fieldPaths = Object.keys(fields);
  const q = new URLSearchParams();
  for (const f of fieldPaths) q.append("updateMask.fieldPaths", f);
  const url =
    `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/barbershops/${encodeURIComponent(
      slug,
    )}?` + q.toString();
  const res = await fetch(url, {
    method: "PATCH",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ fields }),
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`Firestore PATCH: ${res.status} ${t}`);
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }
  if (!WEBHOOK_SECRET || !SA_JSON || !PROJECT_ID) {
    return new Response("Config incompleta (STRIPE_WEBHOOK_SECRET, GOOGLE_SERVICE_ACCOUNT, FIREBASE_PROJECT_ID)", {
      status: 500,
    });
  }
  const rawBody = await req.text();
  const sig = req.headers.get("stripe-signature");
  if (!sig) {
    return new Response("No signature", { status: 400 });
  }

  const stripe = new Stripe(STRIPE_KEY || "sk_test_placeholder", {
    apiVersion: "2024-11-20.acacia",
  });

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(rawBody, sig, WEBHOOK_SECRET);
  } catch (e) {
    console.error("Assinatura inválida", e);
    return new Response(`Webhook Error: ${(e as Error).message}`, { status: 400 });
  }

  const access = await getAccessToken();

  try {
    if (event.type === "checkout.session.completed") {
      const session = event.data.object as Stripe.Checkout.Session;
      if (session.mode === "subscription" && session.status === "complete") {
        const slug = session.client_reference_id ?? session.metadata?.slug;
        const subId = session.subscription
          ? (typeof session.subscription === "string"
            ? session.subscription
            : session.subscription.id)
          : null;
        const customerId = session.customer
          ? (typeof session.customer === "string"
            ? session.customer
            : session.customer.id)
          : null;
        if (slug && subId && customerId) {
          const payFailed = session.payment_status && session.payment_status !== "paid" &&
            session.payment_status !== "no_payment_required";
          const st = payFailed ? "past_due" : "active";
          await firestorePatchBarbershop(access, slug, {
            subscriptionStatus: strValue(st),
            plan: strValue("pro"),
            stripeCustomerId: strValue(customerId),
            stripeSubscriptionId: strValue(subId),
            updatedAt: tsValue(),
          });
        }
      }
    } else if (
      event.type === "customer.subscription.updated" ||
      event.type === "customer.subscription.deleted"
    ) {
      const sub = event.data.object as Stripe.Subscription;
      const subId = sub.id;
      const customerId = typeof sub.customer === "string"
        ? sub.customer
        : sub.customer.id;
      let slug = sub.metadata?.slug;
      if (!slug) {
        slug = await firestoreRunQuery(access, "stripeSubscriptionId", subId) ??
          undefined;
      }
      if (!slug) {
        slug = (await firestoreRunQuery(
          access,
          "stripeCustomerId",
          customerId,
        )) ?? undefined;
      }
      if (slug) {
        const st = event.type === "customer.subscription.deleted"
          ? "canceled"
          : mapSubscriptionStatusToApp(sub.status);
        await firestorePatchBarbershop(access, slug, {
          stripeCustomerId: strValue(customerId),
          stripeSubscriptionId: strValue(subId),
          subscriptionStatus: strValue(st),
          updatedAt: tsValue(),
        });
      } else {
        if (STRIPE_KEY) {
          const s = await new Stripe(STRIPE_KEY, {
            apiVersion: "2024-11-20.acacia",
          }).subscriptions.retrieve(subId);
          const fromMeta = s.metadata?.slug;
          if (fromMeta) {
            const st = event.type === "customer.subscription.deleted"
              ? "canceled"
              : mapSubscriptionStatusToApp(sub.status);
            await firestorePatchBarbershop(access, fromMeta, {
              stripeCustomerId: strValue(customerId),
              stripeSubscriptionId: strValue(subId),
              subscriptionStatus: strValue(st),
              updatedAt: tsValue(),
            });
          } else {
            console.warn("Webhook: slug não encontrado para", subId);
          }
        } else {
          console.warn("Webhook: slug não mapeado; defina STRIPE_SECRET_KEY", subId);
        }
      }
    } else if (
      event.type === "invoice.paid" ||
      event.type === "invoice.payment_succeeded"
    ) {
      const inv = event.data.object as Stripe.Invoice;
      const subId = inv.subscription
        ? (typeof inv.subscription === "string"
          ? inv.subscription
          : inv.subscription.id)
        : null;
      if (subId) {
        const slug = await firestoreRunQuery(
          access,
          "stripeSubscriptionId",
          subId,
        );
        if (slug) {
          await firestorePatchBarbershop(access, slug, {
            subscriptionStatus: strValue("active"),
            updatedAt: tsValue(),
          });
        }
      }
    } else if (event.type === "invoice.payment_failed") {
      const inv = event.data.object as Stripe.Invoice;
      const subId = inv.subscription
        ? (typeof inv.subscription === "string"
          ? inv.subscription
          : inv.subscription.id)
        : null;
      if (subId) {
        const slug = await firestoreRunQuery(
          access,
          "stripeSubscriptionId",
          subId,
        );
        if (slug) {
          await firestorePatchBarbershop(access, slug, {
            subscriptionStatus: strValue("past_due"),
            updatedAt: tsValue(),
          });
        }
      }
    }
  } catch (e) {
    console.error(e);
    return new Response(
      JSON.stringify({ error: (e as Error).message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  return new Response(JSON.stringify({ received: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
