import type { ReactNode } from "react";
import { useState, useMemo, useEffect, useRef } from "react";
import {
  Bell,
  ChevronRight,
  Clock,
  Eye,
  Leaf,
  Pin,
  Up,
  Down,
  Verified,
  Tag,
  Wallet as WalletIcon,
  Search,
  X,
  Check,
  ChevronLeft
} from "./icons";
import {
  marketPrices,
  inr,
  type Listing,
  type Activity,
  type BuyRequirement,
  type ChatThread,
} from "./data";

/* ── App bar with Role Switcher ──────────────── */
interface AppBarProps {
  role: "farmer" | "dealer";
  onToggleRole: () => void;
  unreadCount?: number;
}

export function AppBar({ role, onToggleRole, unreadCount = 2 }: AppBarProps) {
  const isFarmer = role === "farmer";
  return (
    <header className="appbar">
      <div className="appbar__avatar" aria-hidden style={{ background: "var(--bg)", color: "var(--primary)" }}>
        {isFarmer ? "L" : "A"}
      </div>
      <div className="appbar__id">
        <div className="appbar__hi">Logged in as</div>
        <div className="appbar__name">
          {isFarmer ? "Lakshmi (Farmer)" : "Anand (Dealer)"}
          <Verified size={16} />
        </div>
      </div>

      {/* Role Toggle Switcher */}
      <div className="role-switch">
        <button
          className={`role-switch__btn ${isFarmer ? "role-switch__btn--active" : ""}`}
          onClick={() => role !== "farmer" && onToggleRole()}
        >
          Farmer
        </button>
        <button
          className={`role-switch__btn ${!isFarmer ? "role-switch__btn--active" : ""}`}
          onClick={() => role !== "dealer" && onToggleRole()}
        >
          Dealer
        </button>
      </div>

      <button className="iconbtn" aria-label="Notifications" style={{ marginLeft: 8 }}>
        <Bell size={22} />
        {unreadCount > 0 && <span className="iconbtn__dot" aria-hidden />}
      </button>
    </header>
  );
}

/* ── Wallet strip ─────────────────────────── */
interface WalletStripProps {
  role: "farmer" | "dealer";
  balance: number;
  pendingPayout: number;
  onWithdraw: () => void;
}

export function WalletStrip({ role, balance, pendingPayout, onWithdraw }: WalletStripProps) {
  const isFarmer = role === "farmer";
  return (
    <section className="wallet reveal" aria-label="Your earnings">
      <div className="wallet__main">
        <div className="wallet__label">
          <WalletIcon size={14} /> {isFarmer ? "Wallet balance" : "Dealer funds"}
        </div>
        <div className="wallet__amount num">{inr(balance)}</div>
        {isFarmer && (
          <div className="wallet__pending">
            <b>{inr(pendingPayout)}</b> in escrow · releases on delivery
          </div>
        )}
        {!isFarmer && (
          <div className="wallet__pending">
            Active buying budget for APMC trading
          </div>
        )}
      </div>
      <button className="wallet__cta" onClick={onWithdraw}>
        {isFarmer ? "Withdraw" : "Add Funds"}
      </button>
    </section>
  );
}

/* ── Price strip ──────────────────────────── */
export function PriceStrip() {
  return (
    <section className="sec" aria-label="Today's mandi prices">
      <div className="sec__head">
        <div>
          <div className="sec__title">Today's mandi price</div>
          <div className="sec__sub">Live from eNAM · Kolar APMC</div>
        </div>
        <a className="link" href="#prices">
          All <ChevronRight size={14} />
        </a>
      </div>
      <div className="prices">
        {marketPrices.map((m) => {
          const up = m.changePct >= 0;
          return (
            <div className="price" key={m.crop}>
              <div className="price__top">
                <span className="price__emoji" aria-hidden>
                  {m.emoji}
                </span>
                <span className="price__crop">{m.crop}</span>
              </div>
              <div className="price__val num">
                {inr(m.price)}
                <span className="price__unit">/{m.unit}</span>
              </div>
              <div className={`chg ${up ? "chg--up" : "chg--down"}`}>
                {up ? <Up size={13} /> : <Down size={13} />}
                {Math.abs(m.changePct)}%
              </div>
            </div>
          );
        })}
      </div>
    </section>
  );
}

/* ── Status pill ──────────────────────────── */
function StatusPill({ l }: { l: Listing }) {
  if (l.status === "sold")
    return <span className="pill pill--sold">Sold</span>;
  if (l.status === "offers")
    return (
      <span className="pill pill--offers">
        <Tag size={12} /> {l.offers} offers
      </span>
    );
  return <span className="pill pill--live">Live</span>;
}

/* ── Listing card ─────────────────────────── */
interface ListingCardProps {
  l: Listing;
  i: number;
  onSelect: (l: Listing) => void;
}

export function ListingCard({ l, i, onSelect }: ListingCardProps) {
  const over = l.price >= l.marketPrice;
  return (
    <button
      className="card reveal"
      style={{ animationDelay: `${i * 55}ms` }}
      aria-label={`${l.crop}, ${l.qty} ${l.unit}, grade ${l.grade}`}
      onClick={() => onSelect(l)}
    >
      <div className="card__thumb" aria-hidden>
        {l.emoji}
        {l.organic && (
          <span className="card__organic" title="Organic">
            <Leaf size={13} />
          </span>
        )}
      </div>
      <div className="card__body">
        <div className="card__row1">
          <span className="card__crop">{l.crop}</span>
          <span className="card__qty num">
            {l.qty} {l.unit}
          </span>
          <span className={`grade grade--${l.grade}`}>Grade {l.grade}</span>
        </div>
        <div className="card__price">
          <span className="card__ask num">{inr(l.price)}</span>
          <span className="card__per">/quintal</span>
          <span className={`card__vs ${over ? "card__vs--over" : "card__vs--under"}`}>
            {over ? "▲" : "▼"} {inr(Math.abs(l.price - l.marketPrice))} vs mandi
          </span>
        </div>
        <div className="card__meta">
          {l.harvestIn === 0 ? (
            <span className="pill pill--ready">Ready now</span>
          ) : (
            <span>
              <Clock size={13} /> {l.harvestIn}d to harvest
            </span>
          )}
          <span>
            <Eye size={13} /> {l.views}
          </span>
          <span>
            <Pin size={13} /> {l.location}
          </span>
        </div>
      </div>
      <div style={{ display: "flex", flexDirection: "column", justifyContent: "space-between", alignItems: "flex-end" }}>
        <StatusPill l={l} />
        <ChevronRight size={18} color="var(--muted)" style={{ marginTop: 12 }} />
      </div>
    </button>
  );
}

/* ── Farmer listings view ─────────────────── */
interface MyListingsProps {
  listings: Listing[];
  onSelectListing: (l: Listing) => void;
}

export function MyListings({ listings, onSelectListing }: MyListingsProps) {
  const liveCount = listings.filter((l) => l.status !== "sold").length;
  return (
    <section className="sec" aria-label="Your listings">
      <div className="sec__head">
        <div className="sec__title">Your listings</div>
        <a className="link" href="#listings">
          {liveCount} active <ChevronRight size={14} />
        </a>
      </div>
      <div className="feed">
        {listings.map((l, i) => (
          <ListingCard key={l.id} l={l} i={i} onSelect={onSelectListing} />
        ))}
        {listings.length === 0 && (
          <div className="empty-state">No listings posted yet. Tap "List produce" to start!</div>
        )}
      </div>
    </section>
  );
}

/* ── Activity Feed ────────────────────────── */
const actIcon = (a: Activity): ReactNode => {
  if (a.kind === "payout") return <WalletIcon size={20} />;
  if (a.kind === "message") return <ChevronRight size={20} />;
  return <Tag size={20} />;
};

interface ActivityFeedProps {
  activities: Activity[];
  onSelectActivity: (a: Activity) => void;
}

export function ActivityFeed({ activities, onSelectActivity }: ActivityFeedProps) {
  return (
    <section className="sec" aria-label="Recent activity">
      <div className="sec__head">
        <div className="sec__title">Activity</div>
        <a className="link" href="#activity">
          All <ChevronRight size={14} />
        </a>
      </div>
      <ul className="acts">
        {activities.map((a) => {
          const incoming = a.kind === "payout";
          const cls =
            a.kind === "payout"
              ? "act__icon--payout"
              : a.kind === "message"
                ? "act__icon--message"
                : "act__icon--offer";
          return (
            <li key={a.id}>
              <button className="act" onClick={() => onSelectActivity(a)}>
                <span className={`act__icon ${cls}`} aria-hidden>
                  {actIcon(a)}
                </span>
                <span className="act__body">
                  <span className="act__line1">
                    <span className="act__who">{a.who}</span>
                    <span className="act__type">{a.whoType}</span>
                    {a.unread && <span className="act__unread" aria-label="new" />}
                  </span>
                  <span className="act__line2">
                    {a.kind === "offer" && (
                      <>
                        Offered <b>{inr(a.amount || 0)}</b>/quintal for your <b>{a.crop}</b>
                      </>
                    )}
                    {a.kind === "payout" && (
                      <>
                        Escrow released · <b>{a.crop}</b> order of <b>{inr(a.amount || 0)}</b>
                      </>
                    )}
                    {a.kind === "message" && (
                      <>
                        New message about your <b>{a.crop}</b> listing
                      </>
                    )}
                  </span>
                </span>
                <span className="act__right">
                  <span className="act__when">{a.when}</span>
                  {a.amount != null && (
                    <div className={`act__amt ${incoming ? "act__amt--in" : ""} num`}>
                      {incoming ? "+" : ""}
                      {inr(a.amount)}
                    </div>
                  )}
                </span>
              </button>
            </li>
          );
        })}
      </ul>
    </section>
  );
}

/* ── Buyers (Buy Requirements) view for Farmer ── */
interface BuyersViewProps {
  requirements: BuyRequirement[];
  onStartChat: (name: string, role: string, crop: string) => void;
}

export function BuyersView({ requirements, onStartChat }: BuyersViewProps) {
  const [search, setSearch] = useState("");
  const filtered = requirements.filter((r) =>
    r.crop.toLowerCase().includes(search.toLowerCase()) ||
    r.dealerName.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="scroll">
      <div className="search-bar">
        <Search size={18} color="var(--muted)" style={{ position: "absolute", left: 28, top: 28 }} />
        <input
          className="input search-input"
          placeholder="Search crop or buyer requirements..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{ paddingLeft: 42 }}
        />
      </div>

      <section className="sec" style={{ paddingTop: 8 }}>
        <div className="sec__title" style={{ marginBottom: 12 }}>Open Buy Requirements</div>
        <div className="feed">
          {filtered.map((r, i) => (
            <div key={r.id} className="card reveal" style={{ animationDelay: `${i * 50}ms` }}>
              <div className="card__thumb" aria-hidden>{r.emoji}</div>
              <div className="card__body">
                <div className="card__row1">
                  <span className="card__crop">{r.crop}</span>
                  <span className="card__qty num">{r.qty} {r.unit}</span>
                  <span className={`grade grade--${r.grade}`}>Grade {r.grade}</span>
                </div>
                <div className="card__price" style={{ marginTop: 4 }}>
                  <span className="card__ask num" style={{ color: "var(--accent)" }}>Max {inr(r.maxPrice)}</span>
                  <span className="card__per">/quintal</span>
                </div>
                <div className="card__meta" style={{ marginTop: 6 }}>
                  <span style={{ fontWeight: 600, color: "var(--ink)" }}>{r.dealerName}</span>
                  <span><Pin size={12} /> {r.location}</span>
                </div>
              </div>
              <div style={{ display: "flex", alignItems: "center" }}>
                <button
                  className="btn btn--primary"
                  onClick={() => onStartChat(r.dealerName, "Dealer", r.crop)}
                  style={{ height: 38, fontSize: "0.8125rem", paddingInline: 12 }}
                >
                  Contact
                </button>
              </div>
            </div>
          ))}
          {filtered.length === 0 && (
            <div className="empty-state">No matching buyer requirements found.</div>
          )}
        </div>
      </section>
    </div>
  );
}

/* ── Chats list tab ──────────────────────── */
interface ChatsViewProps {
  chats: ChatThread[];
  onOpenChat: (c: ChatThread) => void;
}

export function ChatsView({ chats, onOpenChat }: ChatsViewProps) {
  return (
    <div className="scroll">
      <section className="sec">
        <div className="sec__title" style={{ marginBottom: 12 }}>Your Conversations</div>
        <ul className="acts">
          {chats.map((c) => {
            const lastMsg = c.messages[c.messages.length - 1];
            return (
              <li key={c.id}>
                <button className="act" onClick={() => onOpenChat(c)}>
                  <div className="appbar__avatar" style={{ background: "var(--surface-2)", color: "var(--primary)" }}>
                    {c.partnerName[0]}
                  </div>
                  <div className="act__body">
                    <div className="act__line1">
                      <span className="act__who">{c.partnerName}</span>
                      <span className="act__type">{c.partnerRole} · {c.crop}</span>
                    </div>
                    <div className="act__line2" style={{ textOverflow: "ellipsis", overflow: "hidden", whiteSpace: "nowrap" }}>
                      {lastMsg ? `${lastMsg.sender === "farmer" ? "You: " : ""}${lastMsg.text}` : "No messages yet"}
                    </div>
                  </div>
                  <div className="act__right">
                    <span className="act__when">{lastMsg ? lastMsg.timestamp : ""}</span>
                  </div>
                </button>
              </li>
            );
          })}
          {chats.length === 0 && (
            <div className="empty-state">No chats active yet. Interact with listings to start chatting.</div>
          )}
        </ul>
      </section>
    </div>
  );
}

/* ── Profile page tab ────────────────────── */
interface ProfileViewProps {
  role: "farmer" | "dealer";
  onLogoutToggle: () => void;
}

export function ProfileView({ role, onLogoutToggle }: ProfileViewProps) {
  const isFarmer = role === "farmer";
  return (
    <div className="scroll">
      <section className="sec" style={{ textAlign: "center", paddingBlock: 24 }}>
        <div className="appbar__avatar" style={{ width: 80, height: 80, fontSize: "2rem", marginInline: "auto", marginBottom: 12, background: "var(--primary-tint)", color: "var(--primary)" }}>
          {isFarmer ? "L" : "A"}
        </div>
        <h2 className="done__title">{isFarmer ? "Lakshmi" : "Anand"}</h2>
        <p className="sec__sub">{isFarmer ? "Verified Farmer · Kolar, KA" : "Anand Traders · GST Registered"}</p>
        <div className={`pill ${isFarmer ? "pill--live" : "pill--offers"}`} style={{ marginTop: 8, fontSize: "0.8125rem", padding: "4px 12px" }}>
          <Verified size={14} /> Trust Score: {isFarmer ? "4.8 ★" : "4.9 ★"}
        </div>
      </section>

      <div className="divider" />

      <section className="sec">
        <div className="sec__title" style={{ marginBottom: 12 }}>KYC Verification Status</div>
        <div className="review" style={{ background: "var(--surface)" }}>
          <div className="review__row">
            <span className="review__k">Identity (Aadhaar / PAN)</span>
            <span className="review__v" style={{ color: "var(--ok)", fontWeight: 600 }}>✓ Verified</span>
          </div>
          <div className="review__row">
            <span className="review__k">{isFarmer ? "Land Records (Pahani)" : "GSTIN Registry"}</span>
            <span className="review__v" style={{ color: "var(--ok)", fontWeight: 600 }}>✓ Verified</span>
          </div>
          <div className="review__row">
            <span className="review__k">Bank Account / UPI Link</span>
            <span className="review__v" style={{ color: "var(--ok)", fontWeight: 600 }}>✓ Linked</span>
          </div>
        </div>
      </section>

      <section className="sec" style={{ marginTop: 12 }}>
        <div className="sec__title" style={{ marginBottom: 12 }}>Account Management</div>
        <button className="btn btn--ghost" onClick={onLogoutToggle} style={{ width: "100%", justifyContent: "center" }}>
          Switch Account Role ({isFarmer ? "Dealer View" : "Farmer View"})
        </button>
      </section>
    </div>
  );
}

/* ── Discover Feed tab for Dealer ────────── */
interface DiscoverViewProps {
  listings: Listing[];
  onSelectListing: (l: Listing) => void;
}

export function DiscoverView({ listings, onSelectListing }: DiscoverViewProps) {
  const [search, setSearch] = useState("");
  const [selectedCrop, setSelectedCrop] = useState("All");
  const [selectedGrade, setSelectedGrade] = useState("All");
  const [organicOnly, setOrganicOnly] = useState(false);

  // Available unique crop list for filtering
  const cropsList = useMemo(() => {
    return ["All", ...Array.from(new Set(listings.map((l) => l.crop)))];
  }, [listings]);

  // Filter listings based on inputs
  const filtered = useMemo(() => {
    return listings.filter((l) => {
      if (l.status === "sold") return false;
      const matchesSearch = l.crop.toLowerCase().includes(search.toLowerCase()) ||
        l.farmerName.toLowerCase().includes(search.toLowerCase());
      const matchesCrop = selectedCrop === "All" || l.crop === selectedCrop;
      const matchesGrade = selectedGrade === "All" || l.grade === selectedGrade;
      const matchesOrganic = !organicOnly || l.organic;
      return matchesSearch && matchesCrop && matchesGrade && matchesOrganic;
    });
  }, [listings, search, selectedCrop, selectedGrade, organicOnly]);

  return (
    <div className="scroll">
      <div className="search-bar">
        <Search size={18} color="var(--muted)" style={{ position: "absolute", left: 28, top: 28 }} />
        <input
          className="input search-input"
          placeholder="Search crop, location, or seller name..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{ paddingLeft: 42 }}
        />
      </div>

      {/* Filter Chips Scroll */}
      <div style={{ display: "flex", flexDirection: "column", gap: 8, paddingInline: "var(--s4)", marginBottom: 12 }}>
        {/* Crop filter row */}
        <div style={{ display: "flex", gap: 8, overflowX: "auto", paddingBottom: 4 }} className="hide-scroll">
          {cropsList.map((crop) => (
            <button
              key={crop}
              className={`chip ${selectedCrop === crop ? "chip--active" : ""}`}
              onClick={() => setSelectedCrop(crop)}
            >
              {crop}
            </button>
          ))}
        </div>
        {/* Grade and Organic options row */}
        <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
          {(["All", "A", "B", "C"] as const).map((g) => (
            <button
              key={g}
              className={`chip ${selectedGrade === g ? "chip--active" : ""}`}
              style={{ paddingBlock: 4, paddingInline: 10, fontSize: "0.75rem" }}
              onClick={() => setSelectedGrade(g)}
            >
              Grade {g}
            </button>
          ))}
          <div style={{ flex: 1 }} />
          <button
            className={`chip ${organicOnly ? "chip--active" : ""}`}
            style={{ paddingBlock: 4, paddingInline: 10, fontSize: "0.75rem" }}
            onClick={() => setOrganicOnly(!organicOnly)}
          >
            🌿 Organic
          </button>
        </div>
      </div>

      <PriceStrip />

      <div className="divider" />

      <section className="sec" style={{ paddingTop: 8 }}>
        <div className="sec__head">
          <div className="sec__title">Active Farmer Lots</div>
          <span className="sec__sub">{filtered.length} listings found</span>
        </div>
        <div className="feed">
          {filtered.map((l, i) => (
            <ListingCard key={l.id} l={l} i={i} onSelect={onSelectListing} />
          ))}
          {filtered.length === 0 && (
            <div className="empty-state">No lots match the selected filters.</div>
          )}
        </div>
      </section>
    </div>
  );
}

/* ── Dealer posted requirements view ─────── */
interface DealerRequirementsProps {
  requirements: BuyRequirement[];
  onSelectRequirement?: (r: BuyRequirement) => void;
}

export function DealerRequirements({ requirements }: DealerRequirementsProps) {
  // Show requirements posted by Anand Traders
  const myReqs = requirements.filter((r) => r.dealerName === "Anand Traders");

  return (
    <div className="scroll">
      <section className="sec">
        <div className="sec__head">
          <div>
            <div className="sec__title">Your Buy Requirements</div>
            <div className="sec__sub">Farmers see these and pitch offers directly</div>
          </div>
        </div>
        <div className="feed" style={{ marginTop: 12 }}>
          {myReqs.map((r, i) => (
            <div key={r.id} className="card reveal" style={{ animationDelay: `${i * 50}ms` }}>
              <div className="card__thumb" aria-hidden>{r.emoji}</div>
              <div className="card__body">
                <div className="card__row1">
                  <span className="card__crop">{r.crop}</span>
                  <span className="card__qty num">{r.qty} {r.unit}</span>
                  <span className={`grade grade--${r.grade}`}>Grade {r.grade}</span>
                </div>
                <div className="card__price" style={{ marginTop: 4 }}>
                  <span className="card__ask num" style={{ color: "var(--accent)" }}>Budget: {inr(r.maxPrice)}</span>
                  <span className="card__per">/quintal</span>
                </div>
                <div className="card__meta" style={{ marginTop: 6 }}>
                  <span><Pin size={12} /> {r.location}</span>
                  <span style={{ color: "var(--ok)", fontWeight: 600 }}>✓ Verified listing</span>
                </div>
              </div>
            </div>
          ))}
          {myReqs.length === 0 && (
            <div className="empty-state">You have not posted any buying requirements yet. Tap "Post Requirement" to start.</div>
          )}
        </div>
      </section>
    </div>
  );
}

/* ── Listing details modal/drawer (Stateful) ── */
interface ListingDetailsDrawerProps {
  l: Listing;
  role: "farmer" | "dealer";
  activities: Activity[];
  onClose: () => void;
  onAcceptOffer: (amount: number, listingId: string, offerWho: string) => void;
  onSubmitOffer: (price: number, qty: number, listingId: string) => void;
  onOpenChat: (partnerName: string, partnerRole: string, crop: string) => void;
}

export function ListingDetailsDrawer({
  l,
  role,
  activities,
  onClose,
  onAcceptOffer,
  onSubmitOffer,
  onOpenChat
}: ListingDetailsDrawerProps) {
  const isFarmer = role === "farmer";
  const [offerPrice, setOfferPrice] = useState(String(l.marketPrice));
  const [offerQty, setOfferQty] = useState(String(l.qty));
  const [offerSubmitted, setOfferSubmitted] = useState(false);

  // filter offers for this listing from activities
  const listingOffers = useMemo(() => {
    return activities.filter((a) => a.listingId === l.id && a.kind === "offer");
  }, [activities, l.id]);

  const priceDiff = l.price - l.marketPrice;
  const isOverMandi = priceDiff >= 0;

  const handleMakeOffer = (e: React.FormEvent) => {
    e.preventDefault();
    const priceNum = Number(offerPrice);
    const qtyNum = Number(offerQty);
    if (priceNum > 0 && qtyNum > 0) {
      onSubmitOffer(priceNum, qtyNum, l.id);
      setOfferSubmitted(true);
      setTimeout(() => {
        onClose();
      }, 1200);
    }
  };

  return (
    <>
      <div className="backdrop" onClick={onClose} />
      <section className="sheet" role="dialog" aria-modal="true" aria-label="Listing Details" style={{ overflowY: "auto" }}>
        <div className="sheet__head">
          <button className="iconbtn" style={{ color: "var(--ink)", marginInline: -8 }} onClick={onClose} aria-label="Close">
            <X size={22} />
          </button>
          <span className="sheet__title">Listing Details</span>
          <span className={`pill ${l.status === "sold" ? "pill--sold" : "pill--live"}`}>
            {l.status === "sold" ? "Sold" : "Active"}
          </span>
        </div>

        <div className="sheet__body">
          {offerSubmitted ? (
            <div className="done" style={{ paddingBlock: 20 }}>
              <div className="done__ring">
                <Check size={42} />
              </div>
              <h2 className="done__title">Bid Submitted!</h2>
              <p className="done__sub">
                Your offer of {inr(Number(offerPrice))}/quintal was sent to Lakshmi. We'll notify you if they accept.
              </p>
            </div>
          ) : (
            <div className="reveal">
              {/* Product header summary */}
              <div style={{ display: "flex", gap: 16, alignItems: "center", marginBottom: 20 }}>
                <div className="card__thumb" style={{ width: 68, height: 68, fontSize: "2rem", flexShrink: 0 }}>
                  {l.emoji}
                </div>
                <div style={{ flex: 1 }}>
                  <h2 className="step__q" style={{ marginBottom: 2 }}>{l.crop} lot</h2>
                  <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
                    <span className="card__qty" style={{ fontSize: "1rem", fontWeight: 600 }}>{l.qty} {l.unit}</span>
                    <span className={`grade grade--${l.grade}`} style={{ fontSize: "0.75rem" }}>Grade {l.grade}</span>
                    {l.organic && <span className="pill pill--ready" style={{ fontSize: "0.6875rem" }}>🌿 Organic</span>}
                  </div>
                </div>
              </div>

              {/* Seller details card */}
              <div className="trust" style={{ background: "var(--surface)", color: "var(--ink)", marginTop: 0, border: "1px solid var(--line)", display: "block" }}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                  <div>
                    <span style={{ fontSize: "0.75rem", color: "var(--muted)", display: "block" }}>SELLER</span>
                    <span style={{ fontWeight: 600, fontSize: "0.9375rem" }}>{l.farmerName}</span>
                    {l.farmerVerified && <span style={{ color: "var(--ok)", fontSize: "0.75rem", marginLeft: 4 }}>✓ Verified Farmer</span>}
                  </div>
                  <div style={{ textAlign: "right" }}>
                    <span style={{ fontSize: "0.75rem", color: "var(--muted)", display: "block" }}>LOCATION</span>
                    <span style={{ fontSize: "0.875rem" }}><Pin size={12} /> {l.location}</span>
                  </div>
                </div>
                {!isFarmer && (
                  <button
                    className="btn btn--ghost"
                    onClick={() => onOpenChat(l.farmerName, "Farmer", l.crop)}
                    style={{ height: 32, fontSize: "0.8125rem", width: "100%", marginTop: 12, justifyContent: "center" }}
                  >
                    Chat with Seller
                  </button>
                )}
              </div>

              {/* Details table */}
              <div className="review" style={{ marginTop: 16 }}>
                <div className="review__row">
                  <span className="review__k">Asking price</span>
                  <span className="review__v">{inr(l.price)}/quintal</span>
                </div>
                <div className="review__row">
                  <span className="review__k">Mandi Rate (APMC live)</span>
                  <span className="review__v">{inr(l.marketPrice)}/quintal</span>
                </div>
                <div className="review__row">
                  <span className="review__k">Price comparison</span>
                  <span className="review__v" style={{ color: isOverMandi ? "var(--ok)" : "var(--accent-press)" }}>
                    {isOverMandi ? "▲" : "▼"} {inr(Math.abs(priceDiff))} vs Mandi
                  </span>
                </div>
                <div className="review__row">
                  <span className="review__k">Ready in</span>
                  <span className="review__v">{l.harvestIn === 0 ? "Ready now (Harvested)" : `${l.harvestIn} days`}</span>
                </div>
              </div>

              {/* Interactive section depending on role */}
              {isFarmer ? (
                /* Farmer View: show bids list and accept buttons */
                <div style={{ marginTop: 24 }}>
                  <h3 className="sec__title" style={{ fontSize: "1rem", marginBottom: 12 }}>Bids &amp; Offers ({listingOffers.length})</h3>
                  <div className="feed">
                    {listingOffers.map((o) => (
                      <div key={o.id} className="review" style={{ padding: 12, display: "flex", justifyContent: "space-between", alignItems: "center", background: o.unread ? "var(--accent-tint)" : "var(--bg)", borderColor: o.unread ? "var(--accent)" : "var(--line)" }}>
                        <div>
                          <div style={{ fontWeight: 600 }}>{o.who} <span className="act__type">{o.whoType}</span></div>
                          <div className="sec__sub" style={{ fontSize: "0.75rem", marginTop: 2 }}>
                            Offered: <b style={{ color: "var(--ink)", fontSize: "0.9375rem" }}>{inr(o.amount || 0)}</b>/quintal for {o.qty || l.qty} {o.unit || l.unit}
                          </div>
                        </div>
                        <div>
                          {l.status === "sold" ? (
                            <span style={{ fontSize: "0.8125rem", color: "var(--muted)", fontWeight: 600 }}>Closed</span>
                          ) : (
                            <button
                              className="btn btn--accent"
                              style={{ height: 36, fontSize: "0.8125rem", paddingInline: 12 }}
                              onClick={() => onAcceptOffer(o.amount || l.price, l.id, o.who)}
                            >
                              Accept
                            </button>
                          )}
                        </div>
                      </div>
                    ))}
                    {listingOffers.length === 0 && (
                      <div className="empty-state">No offers received on this listing yet.</div>
                    )}
                  </div>
                </div>
              ) : (
                /* Dealer View: make offer inputs */
                <div style={{ marginTop: 24 }}>
                  {l.status === "sold" ? (
                    <div className="empty-state" style={{ color: "var(--muted)" }}>This lot has already been sold.</div>
                  ) : (
                    <form onSubmit={handleMakeOffer}>
                      <h3 className="sec__title" style={{ fontSize: "1rem", marginBottom: 12 }}>Make an Offer</h3>
                      <div className="qtyrow" style={{ marginBottom: 16 }}>
                        <div className="field" style={{ flex: 1, marginBottom: 0 }}>
                          <label className="field__label">Offer Price (₹/quintal)</label>
                          <input
                            className="input num"
                            type="number"
                            value={offerPrice}
                            onChange={(e) => setOfferPrice(e.target.value)}
                          />
                        </div>
                        <div className="field" style={{ flex: 1, marginBottom: 0 }}>
                          <label className="field__label">Qty ({l.unit})</label>
                          <input
                            className="input num"
                            type="number"
                            step="any"
                            value={offerQty}
                            onChange={(e) => setOfferQty(e.target.value)}
                          />
                        </div>
                      </div>
                      <div style={{ background: "var(--ok-tint)", padding: 12, borderRadius: "var(--r-md)", fontSize: "0.8125rem", color: "oklch(0.4 0.1 150)", marginBottom: 16, display: "flex", gap: 8, alignItems: "center" }}>
                        <Verified size={16} />
                        <span>Escrow hold of <b>{inr(Number(offerPrice) * Number(offerQty) * (l.unit === "ton" ? 10 : 1))}</b> will be secured on acceptance.</span>
                      </div>
                      <button className="btn btn--primary" style={{ width: "100%" }} type="submit">
                        Submit Bid
                      </button>
                    </form>
                  )}
                </div>
              )}
            </div>
          )}
        </div>
      </section>
    </>
  );
}

/* ── Interactive Chat Screen / Overlay ────── */
interface ChatOverlayProps {
  thread: ChatThread;
  role: "farmer" | "dealer";
  onClose: () => void;
  onSendMessage: (threadId: string, text: string) => void;
}

export function ChatOverlay({ thread, role, onClose, onSendMessage }: ChatOverlayProps) {
  const [text, setText] = useState("");
  const bodyRef = useRef<HTMLDivElement>(null);

  // Auto-scroll chat body to bottom
  useEffect(() => {
    if (bodyRef.current) {
      bodyRef.current.scrollTop = bodyRef.current.scrollHeight;
    }
  }, [thread.messages]);

  const handleSend = (e: React.FormEvent) => {
    e.preventDefault();
    if (text.trim() === "") return;
    onSendMessage(thread.id, text.trim());
    setText("");
  };

  return (
    <>
      <div className="backdrop" onClick={onClose} />
      <section className="sheet" role="dialog" aria-modal="true" style={{ height: "80dvh", display: "flex", flexDirection: "column" }}>
        {/* Chat header */}
        <div className="sheet__head" style={{ flexShrink: 0 }}>
          <button className="iconbtn" style={{ color: "var(--ink)", marginInline: -8 }} onClick={onClose} aria-label="Back">
            <ChevronLeft size={22} />
          </button>
          <div style={{ flex: 1, marginLeft: 8 }}>
            <span className="sheet__title" style={{ fontSize: "1rem", display: "block" }}>{thread.partnerName}</span>
            <span className="sec__sub" style={{ fontSize: "0.75rem" }}>{thread.partnerRole} · Crop: {thread.crop}</span>
          </div>
          <Verified size={18} color="var(--ok)" />
        </div>

        {/* Messaging conversation scroll box */}
        <div
          ref={bodyRef}
          style={{
            flex: 1,
            overflowY: "auto",
            padding: "16px",
            background: "var(--surface)",
            display: "flex",
            flexDirection: "column",
            gap: "12px"
          }}
        >
          {thread.messages.map((m) => {
            const isMe = m.sender === role;
            return (
              <div
                key={m.id}
                style={{
                  alignSelf: isMe ? "flex-end" : "flex-start",
                  maxWidth: "75%",
                  background: isMe ? "var(--primary)" : "var(--bg)",
                  color: isMe ? "var(--on-primary)" : "var(--ink)",
                  padding: "10px 14px",
                  borderRadius: "14px",
                  borderTopRightRadius: isMe ? "2px" : "14px",
                  borderTopLeftRadius: !isMe ? "2px" : "14px",
                  boxShadow: "var(--shadow-sm)",
                  border: isMe ? "none" : "1px solid var(--line)"
                }}
              >
                <div style={{ fontSize: "0.9375rem", lineHeight: "1.4" }}>{m.text}</div>
                <span
                  style={{
                    display: "block",
                    fontSize: "0.6875rem",
                    color: isMe ? "rgba(255,255,255,0.7)" : "var(--muted)",
                    marginTop: "4px",
                    textAlign: "right"
                  }}
                >
                  {m.timestamp}
                </span>
              </div>
            );
          })}
        </div>

        {/* Input box */}
        <form
          onSubmit={handleSend}
          style={{
            padding: "12px",
            borderTop: "1px solid var(--line)",
            display: "flex",
            gap: "8px",
            background: "var(--bg)",
            alignItems: "center",
            flexShrink: 0
          }}
        >
          <input
            className="input"
            placeholder="Type your message..."
            value={text}
            onChange={(e) => setText(e.target.value)}
            style={{ borderRadius: "24px", paddingBlock: "10px", paddingInline: "16px", fontSize: "0.9375rem" }}
          />
          <button
            className="btn btn--primary"
            type="submit"
            style={{
              flex: "0 0 auto",
              width: "44px",
              height: "44px",
              borderRadius: "50%",
              padding: 0,
              minWidth: "auto"
            }}
          >
            <ChevronRight size={22} style={{ transform: "rotate(0deg)" }} />
          </button>
        </form>
      </section>
    </>
  );
}
