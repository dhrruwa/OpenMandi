export type Grade = "A" | "B" | "C";

export type ListingStatus = "live" | "offers" | "sold";

export interface Listing {
  id: string;
  crop: string;
  emoji: string;
  qty: number;
  unit: string;
  grade: Grade;
  organic: boolean;
  price: number; // ₹ per unit, the farmer's ask
  marketPrice: number; // today's mandi price per unit
  harvestIn: number; // days until ready; 0 = ready now
  location: string;
  status: ListingStatus;
  offers: number;
  views: number;
}

export interface MarketPrice {
  crop: string;
  emoji: string;
  price: number; // ₹ per quintal
  unit: string;
  changePct: number; // vs yesterday
}

export interface Activity {
  id: string;
  kind: "offer" | "order" | "message" | "payout";
  who: string;
  whoType: "Exporter" | "Local dealer" | "Company" | "OpenMandi";
  crop: string;
  amount?: number;
  qty?: number;
  unit?: string;
  when: string;
  unread: boolean;
}

export const farmer = {
  name: "Lakshmi",
  village: "Kolar, Karnataka",
  verified: true,
  wallet: 48250,
  pendingPayout: 12400,
};

export const marketPrices: MarketPrice[] = [
  { crop: "Tomato", emoji: "🍅", price: 2400, unit: "quintal", changePct: 8.2 },
  { crop: "Onion", emoji: "🧅", price: 1850, unit: "quintal", changePct: -3.1 },
  { crop: "Potato", emoji: "🥔", price: 1320, unit: "quintal", changePct: 1.4 },
  { crop: "Brinjal", emoji: "🍆", price: 2100, unit: "quintal", changePct: 5.6 },
  { crop: "Chilli", emoji: "🌶️", price: 9800, unit: "quintal", changePct: -1.2 },
  { crop: "Carrot", emoji: "🥕", price: 1700, unit: "quintal", changePct: 2.9 },
];

export const listings: Listing[] = [
  {
    id: "l1",
    crop: "Tomato",
    emoji: "🍅",
    qty: 1.2,
    unit: "ton",
    grade: "A",
    organic: false,
    price: 2600,
    marketPrice: 2400,
    harvestIn: 0,
    location: "Kolar",
    status: "offers",
    offers: 3,
    views: 41,
  },
  {
    id: "l2",
    crop: "Brinjal",
    emoji: "🍆",
    qty: 600,
    unit: "kg",
    grade: "A",
    organic: true,
    price: 2300,
    marketPrice: 2100,
    harvestIn: 4,
    location: "Kolar",
    status: "live",
    offers: 0,
    views: 12,
  },
  {
    id: "l3",
    crop: "Onion",
    emoji: "🧅",
    qty: 2.5,
    unit: "ton",
    grade: "B",
    organic: false,
    price: 1800,
    marketPrice: 1850,
    harvestIn: 0,
    location: "Kolar",
    status: "sold",
    offers: 0,
    views: 88,
  },
];

export const activity: Activity[] = [
  {
    id: "a1",
    kind: "offer",
    who: "Surya Exports",
    whoType: "Exporter",
    crop: "Tomato",
    amount: 2550,
    qty: 1.2,
    unit: "ton",
    when: "12 min ago",
    unread: true,
  },
  {
    id: "a2",
    kind: "offer",
    who: "Anand Traders",
    whoType: "Local dealer",
    crop: "Tomato",
    amount: 2500,
    qty: 1,
    unit: "ton",
    when: "1 hr ago",
    unread: true,
  },
  {
    id: "a3",
    kind: "payout",
    who: "OpenMandi",
    whoType: "OpenMandi",
    crop: "Onion",
    amount: 12400,
    when: "Yesterday",
    unread: false,
  },
  {
    id: "a4",
    kind: "message",
    who: "FreshCo Foods",
    whoType: "Company",
    crop: "Brinjal",
    when: "Yesterday",
    unread: false,
  },
];

export const cropCatalog = [
  { crop: "Tomato", emoji: "🍅", market: 2400 },
  { crop: "Onion", emoji: "🧅", market: 1850 },
  { crop: "Potato", emoji: "🥔", market: 1320 },
  { crop: "Brinjal", emoji: "🍆", market: 2100 },
  { crop: "Chilli", emoji: "🌶️", market: 9800 },
  { crop: "Carrot", emoji: "🥕", market: 1700 },
  { crop: "Cabbage", emoji: "🥬", market: 980 },
  { crop: "Okra", emoji: "🫛", market: 3200 },
];

export const inr = (n: number) =>
  "₹" + n.toLocaleString("en-IN", { maximumFractionDigits: 0 });
