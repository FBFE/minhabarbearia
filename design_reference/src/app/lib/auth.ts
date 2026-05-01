// Mock authentication system - simulates Firebase behavior
interface User {
  uid: string;
  email: string;
  displayName?: string;
}

interface Business {
  id: string;
  name: string;
  slug: string;
  ownerId: string;
  primaryColor: string;
  secondaryColor: string;
  logo?: string;
  backgroundImage?: string;
  trialEndDate?: string;
  subscriptionStatus?: 'trial' | 'active' | 'expired';
}

interface Client {
  id: string;
  businessId: string;
  name: string;
  email: string;
  phone: string;
  birthDate?: string;
  points: number;
  stamps: number;
  totalAppointments: number;
}

const STORAGE_KEYS = {
  USER: 'auth_user',
  BUSINESS: 'business_data',
  CLIENT: 'client_data',
  STAFF: 'staff_data',
  ADMIN_UIDS: ['admin-uid-1'],
};

// Mock user for demo purposes
export const mockOwnerUser: User = {
  uid: 'owner-123',
  email: 'dono@exemplo.com',
  displayName: 'João Silva',
};

export const mockBusiness: Business = {
  id: 'biz-123',
  name: 'Barbearia Moderna',
  slug: 'moderna',
  ownerId: 'owner-123',
  primaryColor: '#8B5CF6',
  secondaryColor: '#EC4899',
  trialEndDate: '2026-04-14',
  subscriptionStatus: 'trial',
};

// Auth functions
export function getCurrentUser(): User | null {
  const userData = localStorage.getItem(STORAGE_KEYS.USER);
  return userData ? JSON.parse(userData) : null;
}

export function setCurrentUser(user: User | null) {
  if (user) {
    localStorage.setItem(STORAGE_KEYS.USER, JSON.stringify(user));
  } else {
    localStorage.removeItem(STORAGE_KEYS.USER);
  }
}

export function login(email: string, password: string): Promise<User> {
  return new Promise((resolve, reject) => {
    setTimeout(() => {
      if (password.length >= 6) {
        const user: User = {
          uid: 'owner-' + Math.random().toString(36).substr(2, 9),
          email,
          displayName: email.split('@')[0],
        };
        setCurrentUser(user);
        resolve(user);
      } else {
        reject(new Error('Senha incorreta'));
      }
    }, 500);
  });
}

export function register(email: string, password: string): Promise<User> {
  return new Promise((resolve, reject) => {
    setTimeout(() => {
      if (password.length >= 6) {
        const user: User = {
          uid: 'owner-' + Math.random().toString(36).substr(2, 9),
          email,
          displayName: email.split('@')[0],
        };
        setCurrentUser(user);
        resolve(user);
      } else {
        reject(new Error('A senha deve ter no mínimo 6 caracteres'));
      }
    }, 500);
  });
}

export function logout() {
  setCurrentUser(null);
  localStorage.removeItem(STORAGE_KEYS.BUSINESS);
  localStorage.removeItem(STORAGE_KEYS.CLIENT);
  localStorage.removeItem(STORAGE_KEYS.STAFF);
}

export function isAdmin(userId: string): boolean {
  return STORAGE_KEYS.ADMIN_UIDS.includes(userId);
}

// Business functions
export function getUserBusiness(userId: string): Business | null {
  const businessData = localStorage.getItem(STORAGE_KEYS.BUSINESS);
  if (businessData) {
    const business = JSON.parse(businessData);
    if (business.ownerId === userId) {
      return business;
    }
  }
  return null;
}

export function getBusinessBySlug(slug: string): Business | null {
  // In a real app, this would fetch from database
  // For demo, return mock business if slug matches
  if (slug === 'moderna' || slug === mockBusiness.slug) {
    return mockBusiness;
  }
  return null;
}

export function saveBusiness(business: Business) {
  localStorage.setItem(STORAGE_KEYS.BUSINESS, JSON.stringify(business));
}

// Client functions
export function getClientData(): Client | null {
  const clientData = localStorage.getItem(STORAGE_KEYS.CLIENT);
  return clientData ? JSON.parse(clientData) : null;
}

export function setClientData(client: Client | null) {
  if (client) {
    localStorage.setItem(STORAGE_KEYS.CLIENT, JSON.stringify(client));
  } else {
    localStorage.removeItem(STORAGE_KEYS.CLIENT);
  }
}

export function clientLogin(email: string, password: string, businessId: string): Promise<Client> {
  return new Promise((resolve, reject) => {
    setTimeout(() => {
      // Mock client login
      const client: Client = {
        id: 'client-' + Math.random().toString(36).substr(2, 9),
        businessId,
        name: 'Maria Santos',
        email,
        phone: '(11) 98765-4321',
        birthDate: '1990-05-15',
        points: 85,
        stamps: 7,
        totalAppointments: 12,
      };
      setClientData(client);
      resolve(client);
    }, 500);
  });
}

export function clientRegister(data: Partial<Client>): Promise<Client> {
  return new Promise((resolve) => {
    setTimeout(() => {
      const client: Client = {
        id: 'client-' + Math.random().toString(36).substr(2, 9),
        businessId: data.businessId || '',
        name: data.name || '',
        email: data.email || '',
        phone: data.phone || '',
        birthDate: data.birthDate,
        points: 0,
        stamps: 0,
        totalAppointments: 0,
      };
      setClientData(client);
      resolve(client);
    }, 500);
  });
}

// Staff functions
export function isStaff(): boolean {
  return localStorage.getItem(STORAGE_KEYS.STAFF) === 'true';
}

export function setStaffStatus(isStaff: boolean) {
  if (isStaff) {
    localStorage.setItem(STORAGE_KEYS.STAFF, 'true');
  } else {
    localStorage.removeItem(STORAGE_KEYS.STAFF);
  }
}
