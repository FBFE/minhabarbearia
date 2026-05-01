import { createBrowserRouter } from "react-router";
import SplashPage from "./pages/SplashPage";
import LoginPage from "./pages/LoginPage";
import RegisterPage from "./pages/RegisterPage";
import AdminPage from "./pages/AdminPage";
import DashboardPage from "./pages/DashboardPage";
import SettingsPage from "./pages/SettingsPage";
import SubscriptionPage from "./pages/SubscriptionPage";
import ClientHomePage from "./pages/client/ClientHomePage";
import ClientAgendaPage from "./pages/client/ClientAgendaPage";
import ClientLoyaltyPage from "./pages/client/ClientLoyaltyPage";
import ClientProfilePage from "./pages/client/ClientProfilePage";
import ClientRegisterPage from "./pages/client/ClientRegisterPage";
import ClientLoginPage from "./pages/client/ClientLoginPage";
import ClientCompleteProfilePage from "./pages/client/ClientCompleteProfilePage";
import StaffLoginPage from "./pages/staff/StaffLoginPage";
import StaffAgendaPage from "./pages/staff/StaffAgendaPage";

export const router = createBrowserRouter([
  {
    path: "/",
    Component: SplashPage,
  },
  {
    path: "/login",
    Component: LoginPage,
  },
  {
    path: "/register",
    Component: RegisterPage,
  },
  {
    path: "/admin",
    Component: AdminPage,
  },
  {
    path: "/dashboard",
    Component: DashboardPage,
  },
  {
    path: "/dashboard/settings",
    Component: SettingsPage,
  },
  {
    path: "/dashboard/assinar",
    Component: SubscriptionPage,
  },
  {
    path: "/b/:slug",
    Component: ClientHomePage,
  },
  {
    path: "/b/:slug/agenda",
    Component: ClientAgendaPage,
  },
  {
    path: "/b/:slug/fidelidade",
    Component: ClientLoyaltyPage,
  },
  {
    path: "/b/:slug/perfil",
    Component: ClientProfilePage,
  },
  {
    path: "/b/:slug/cadastro",
    Component: ClientRegisterPage,
  },
  {
    path: "/b/:slug/login",
    Component: ClientLoginPage,
  },
  {
    path: "/b/:slug/complete-profile",
    Component: ClientCompleteProfilePage,
  },
  {
    path: "/b/:slug/funcionario",
    Component: StaffLoginPage,
  },
  {
    path: "/b/:slug/funcionario/agenda",
    Component: StaffAgendaPage,
  },
]);
