import type { ReactNode } from "react";
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
} from "./icons";
import {
  activity,
  farmer,
  inr,
  listings,
  marketPrices,
  type Activity,
  type Listing,
} from "./data";

/* ── App bar ──────────────────────────────── */
export function AppBar() {
  return (
    <header className="appbar">
      <div className="appbar__avatar" aria-hidden>
        {farmer.name[0]}
      </div>
      <div className="appbar__id">
        <div className="appbar__hi">Good morning</div>
        <div className="appbar__name">
          {farmer.name}
          {farmer.verified && (
            <>
              <Verified size={16} />
              <span className="sr">Verified farmer</span>
            </>
          )}
        </div>
      </div>
      <button className="iconbtn" aria-label="Notifications">
        <Bell size={22} />
        <span className="iconbtn__dot" aria-hidden />
      </button>
    </header>
  );
}

/* ── Wallet strip ─────────────────────────── */
export function WalletStrip() {
  return (
    <section className="wallet reveal" aria-label="Your earnings">
      <div className="wallet__main">
        <div className="wallet__label">
          <WalletIcon size={14} /> Wallet balance
        </div>
        <div className="wallet__amount num">{inr(farmer.wallet)}</div>
        <div className="wallet__pending">
          <b>{inr(farmer.pendingPayout)}</b> in escrow · releases on delivery
        </div>
      </div>
      <button className="wallet__cta">Withdraw</button>
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
function ListingCard({ l, i }: { l: Listing; i: number }) {
  const over = l.price >= l.marketPrice;
  return (
    <button
      className="card reveal"
      style={{ animationDelay: `${i * 55}ms` }}
      aria-label={`${l.crop}, ${l.qty} ${l.unit}, grade ${l.grade}`}
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
        <ChevronRight size={18} color="var(--muted)" />
      </div>
    </button>
  );
}

export function MyListings() {
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
          <ListingCard key={l.id} l={l} i={i} />
        ))}
      </div>
    </section>
  );
}

/* ── Activity ─────────────────────────────── */
const actIcon = (a: Activity): ReactNode => {
  if (a.kind === "payout") return <WalletIcon size={20} />;
  if (a.kind === "message") return <ChevronRight size={20} />;
  return <Tag size={20} />;
};

export function ActivityFeed() {
  return (
    <section className="sec" aria-label="Recent activity">
      <div className="sec__head">
        <div className="sec__title">Activity</div>
        <a className="link" href="#activity">
          All <ChevronRight size={14} />
        </a>
      </div>
      <ul className="acts">
        {activity.map((a) => {
          const incoming = a.kind === "payout";
          const cls =
            a.kind === "payout"
              ? "act__icon--payout"
              : a.kind === "message"
                ? "act__icon--message"
                : "act__icon--offer";
          return (
            <li key={a.id}>
              <button className="act">
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
                        Offered for your <b>{a.crop}</b> · {a.qty} {a.unit}
                      </>
                    )}
                    {a.kind === "payout" && (
                      <>
                        Escrow released · <b>{a.crop}</b> order
                      </>
                    )}
                    {a.kind === "message" && (
                      <>
                        New message about <b>{a.crop}</b>
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
