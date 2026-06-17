import { useState } from "react";
import {
  AppBar,
  WalletStrip,
  PriceStrip,
  MyListings,
  ActivityFeed,
} from "./components";
import CreateListing from "./CreateListing";
import { Chat, Home, Plus, Search, User } from "./icons";

const TABS = [
  { id: "home", label: "Home", Icon: Home },
  { id: "search", label: "Buyers", Icon: Search },
  { id: "spacer", label: "", Icon: Home },
  { id: "chat", label: "Chats", Icon: Chat },
  { id: "profile", label: "Profile", Icon: User },
] as const;

export default function App() {
  const [tab, setTab] = useState("home");
  const [creating, setCreating] = useState(false);

  return (
    <div className="shell">
      <AppBar />

      <main className="scroll">
        <WalletStrip />
        <PriceStrip />
        <div className="divider" />
        <MyListings />
        <div className="divider" />
        <ActivityFeed />
      </main>

      <button className="fab" onClick={() => setCreating(true)}>
        <Plus size={20} /> List produce
      </button>

      <nav className="tabs" aria-label="Primary">
        {TABS.map((t) =>
          t.id === "spacer" ? (
            <span key="spacer" className="tab tab--spacer" aria-hidden />
          ) : (
            <button
              key={t.id}
              className={`tab ${tab === t.id ? "tab--active" : ""}`}
              aria-current={tab === t.id ? "page" : undefined}
              onClick={() => setTab(t.id)}
            >
              <t.Icon size={23} />
              {t.label}
            </button>
          ),
        )}
      </nav>

      {creating && <CreateListing onClose={() => setCreating(false)} />}
    </div>
  );
}
