import { useState } from "react";
import {
  AppBar,
  WalletStrip,
  PriceStrip,
  MyListings,
  ActivityFeed,
  BuyersView,
  ChatsView,
  ProfileView,
  DiscoverView,
  DealerRequirements,
  ListingDetailsDrawer,
  ChatOverlay
} from "./components";
import CreateListing from "./CreateListing";
import CreateRequirement from "./CreateRequirement";
import { Chat, Home, Plus, Search, User } from "./icons";
import {
  listings as initialListings,
  activity as initialActivity,
  defaultRequirements,
  defaultChats,
  type Listing,
  type Activity,
  type BuyRequirement,
  type ChatThread,
  type Message
} from "./data";

export default function App() {
  const [role, setRole] = useState<"farmer" | "dealer">("farmer");
  const [tab, setTab] = useState("home");
  const [creating, setCreating] = useState(false); // Farmer create listing modal
  const [postingReq, setPostingReq] = useState(false); // Dealer post requirement modal

  // App States
  const [listings, setListings] = useState<Listing[]>(initialListings);
  const [activities, setActivities] = useState<Activity[]>(initialActivity);
  const [requirements, setRequirements] = useState<BuyRequirement[]>(defaultRequirements);
  const [chats, setChats] = useState<ChatThread[]>(defaultChats);
  const [farmerWallet, setFarmerWallet] = useState(48250);
  const [farmerPending, setFarmerPending] = useState(12400);
  const [dealerWallet, setDealerWallet] = useState(150000);

  // Overlays / Details
  const [selectedListing, setSelectedListing] = useState<Listing | null>(null);
  const [activeChat, setActiveChat] = useState<ChatThread | null>(null);

  // Calculate dynamic unread activity count for tab badge
  const unreadActivityCount = activities.filter((a) => a.unread).length;

  const handleToggleRole = () => {
    const nextRole = role === "farmer" ? "dealer" : "farmer";
    setRole(nextRole);
    setTab(nextRole === "farmer" ? "home" : "discover");
    // Close overlays when switching roles
    setSelectedListing(null);
    setActiveChat(null);
  };

  // Convert quantities to quintals for monetary calculations
  const getQtyInQuintals = (qty: number, unit: string) => {
    const u = unit.toLowerCase();
    if (u === "ton" || u === "tons") return qty * 10;
    if (u === "kg" || u === "kgs") return qty / 100;
    return qty;
  };

  // Farmer accepts bid
  const handleAcceptOffer = (pricePerQuintal: number, listingId: string, offerWho: string) => {
    const listing = listings.find((l) => l.id === listingId);
    if (!listing) return;

    const qtyQuintals = getQtyInQuintals(listing.qty, listing.unit);
    const totalAmount = Math.round(pricePerQuintal * qtyQuintals);

    // Update Listing status to sold
    setListings((prev) =>
      prev.map((l) => (l.id === listingId ? { ...l, status: "sold" } : l))
    );

    // Move funds into farmer's wallet and clear from escrow
    setFarmerWallet((w) => w + totalAmount);
    setFarmerPending((p) => Math.max(0, p - 6000)); // Simulating escrow drawdown

    // Log payout activity
    const newActivity: Activity = {
      id: `a-${Date.now()}`,
      kind: "payout",
      who: offerWho,
      whoType: "Local dealer",
      crop: listing.crop,
      amount: totalAmount,
      when: "Just now",
      unread: true,
      listingId: listing.id,
    };
    setActivities((prev) => [newActivity, ...prev]);

    // Close details drawer
    setSelectedListing((curr) => curr && curr.id === listingId ? { ...curr, status: "sold" } : curr);
  };

  // Dealer submits bid
  const handleDealerSubmitOffer = (pricePerQuintal: number, qty: number, listingId: string) => {
    const listing = listings.find((l) => l.id === listingId);
    if (!listing) return;

    // Increment offers count and set status to "offers"
    setListings((prev) =>
      prev.map((l) =>
        l.id === listingId
          ? { ...l, offers: l.offers + 1, status: "offers" as const }
          : l
      )
    );

    // Create bid activity
    const newActivity: Activity = {
      id: `a-${Date.now()}`,
      kind: "offer",
      who: "Anand Traders",
      whoType: "Local dealer",
      crop: listing.crop,
      amount: pricePerQuintal,
      qty: qty,
      unit: listing.unit,
      when: "Just now",
      unread: true,
      listingId: listing.id,
    };
    setActivities((prev) => [newActivity, ...prev]);

    // Debit budget representing escrow hold
    const qtyQuintals = getQtyInQuintals(qty, listing.unit);
    const bidValue = Math.round(pricePerQuintal * qtyQuintals);
    setDealerWallet((w) => Math.max(0, w - bidValue));

    // Update local drawer state if open
    setSelectedListing((curr) =>
      curr && curr.id === listingId
        ? { ...curr, offers: curr.offers + 1, status: "offers" as const }
        : curr
    );
  };

  // Handle opening a chat with a specific dealer/farmer
  const handleOpenChat = (partnerName: string, partnerRole: string, crop: string) => {
    const existing = chats.find(
      (c) => c.partnerName === partnerName && c.crop === crop
    );
    if (existing) {
      setActiveChat(existing);
    } else {
      const newThread: ChatThread = {
        id: `c-${Date.now()}`,
        partnerName,
        partnerRole,
        crop,
        messages: [],
      };
      setChats((prev) => [newThread, ...prev]);
      setActiveChat(newThread);
    }
    setTab("chat");
  };

  // Handle messages in active conversation
  const handleSendMessage = (threadId: string, text: string) => {
    const timeString = new Date().toLocaleTimeString([], {
      hour: "2-digit",
      minute: "2-digit",
    });
    const newMsg: Message = {
      id: `m-${Date.now()}`,
      sender: role,
      text,
      timestamp: timeString,
    };

    // Update conversation thread
    setChats((prev) =>
      prev.map((c) => {
        if (c.id === threadId) {
          return { ...c, messages: [...c.messages, newMsg] };
        }
        return c;
      })
    );

    // Keep active chat thread overlay reference updated
    setActiveChat((curr) =>
      curr && curr.id === threadId ? { ...curr, messages: [...curr.messages, newMsg] } : curr
    );

    // Simulated Auto-responder Reply
    setTimeout(() => {
      const partnerRole = role === "farmer" ? "dealer" : "farmer";
      const responses = [
        "Sounds good. Can you verify the grade specs before we seal the deal?",
        `I am interested in this lot of ${activeChat?.crop || "produce"}. What is your final price?`,
        "Let's route this trade through the OpenMandi escrow system to be safe.",
        "Can we arrange pickup from Kolar APMC this Friday?",
        "Yes, let's proceed with this. Please confirm order details on the dashboard."
      ];
      const randomReply = responses[Math.floor(Math.random() * responses.length)];

      const replyMsg: Message = {
        id: `m-${Date.now() + 1}`,
        sender: partnerRole,
        text: randomReply,
        timestamp: new Date().toLocaleTimeString([], {
          hour: "2-digit",
          minute: "2-digit",
        }),
      };

      setChats((prev) =>
        prev.map((c) => {
          if (c.id === threadId) {
            return { ...c, messages: [...c.messages, replyMsg] };
          }
          return c;
        })
      );

      // Refresh active thread if user still has it open
      setActiveChat((curr) =>
        curr && curr.id === threadId ? { ...curr, messages: [...curr.messages, replyMsg] } : curr
      );

      // Trigger notification unread flag on messages
      const newMsgAct: Activity = {
        id: `a-${Date.now()}`,
        kind: "message",
        who: activeChat?.partnerName || "User",
        whoType: partnerRole === "farmer" ? "Exporter" : "Exporter",
        crop: activeChat?.crop || "Produce",
        when: "Just now",
        unread: true,
      };
      setActivities((prev) => [newMsgAct, ...prev]);

    }, 1500);
  };

  // Farmer publishes listing
  const handlePublishListing = (newLot: {
    crop: string;
    emoji: string;
    qty: number;
    unit: string;
    grade: "A" | "B" | "C";
    organic: boolean;
    price: number;
    marketPrice: number;
    harvestIn: number;
    location: string;
  }) => {
    const created: Listing = {
      ...newLot,
      id: `l-${Date.now()}`,
      offers: 0,
      views: 1,
      status: "live",
      farmerName: "Lakshmi",
      farmerVerified: true,
    };
    setListings((prev) => [created, ...prev]);
  };

  // Dealer posts buy requirement
  const handlePublishRequirement = (newReq: {
    crop: string;
    emoji: string;
    qty: number;
    unit: string;
    grade: "A" | "B" | "C";
    maxPrice: number;
    location: string;
  }) => {
    const created: BuyRequirement = {
      ...newReq,
      id: `r-${Date.now()}`,
      dealerName: "Anand Traders",
    };
    setRequirements((prev) => [created, ...prev]);
  };

  // Connect active overlays from activity cards
  const handleSelectActivity = (a: Activity) => {
    // If it's a message, open chat
    if (a.kind === "message") {
      const thread = chats.find((c) => c.partnerName === a.who && c.crop === a.crop);
      if (thread) {
        setActiveChat(thread);
        setTab("chat");
      } else {
        handleOpenChat(a.who, a.whoType, a.crop);
      }
    } else if (a.listingId) {
      // If it has listingId, open listing details
      const listing = listings.find((l) => l.id === a.listingId);
      if (listing) setSelectedListing(listing);
    }
    // Mark activity as read
    setActivities((prev) =>
      prev.map((act) => (act.id === a.id ? { ...act, unread: false } : act))
    );
  };

  // Bottom Tabs navigation definitions
  const tabsConfig = role === "farmer"
    ? [
        { id: "home", label: "Home", Icon: Home },
        { id: "search", label: "Buyers", Icon: Search },
        { id: "spacer", label: "", Icon: Home },
        { id: "chat", label: "Chats", Icon: Chat },
        { id: "profile", label: "Profile", Icon: User },
      ]
    : [
        { id: "discover", label: "Discover", Icon: Home },
        { id: "requirements", label: "Requirements", Icon: Search },
        { id: "spacer", label: "", Icon: Home },
        { id: "chat", label: "Chats", Icon: Chat },
        { id: "profile", label: "Profile", Icon: User },
      ];

  return (
    <div className="shell">
      <AppBar role={role} onToggleRole={handleToggleRole} unreadCount={unreadActivityCount} />

      <main className="scroll">
        {role === "farmer" ? (
          <>
            {tab === "home" && (
              <>
                <WalletStrip
                  role="farmer"
                  balance={farmerWallet}
                  pendingPayout={farmerPending}
                  onWithdraw={() => {
                    alert("Withdrawing ₹" + farmerWallet + " to linked bank account!");
                    setFarmerWallet(0);
                  }}
                />
                <PriceStrip />
                <div className="divider" />
                <MyListings listings={listings.filter((l) => l.farmerName === "Lakshmi")} onSelectListing={setSelectedListing} />
                <div className="divider" />
                <ActivityFeed activities={activities} onSelectActivity={handleSelectActivity} />
              </>
            )}
            {tab === "search" && (
              <BuyersView requirements={requirements} onStartChat={handleOpenChat} />
            )}
            {tab === "chat" && (
              <ChatsView chats={chats} onOpenChat={setActiveChat} />
            )}
            {tab === "profile" && (
              <ProfileView role="farmer" onLogoutToggle={handleToggleRole} />
            )}
          </>
        ) : (
          <>
            {tab === "discover" && (
              <DiscoverView listings={listings} onSelectListing={setSelectedListing} />
            )}
            {tab === "requirements" && (
              <>
                <WalletStrip
                  role="dealer"
                  balance={dealerWallet}
                  pendingPayout={0}
                  onWithdraw={() => {
                    const funds = prompt("Enter funds to add (₹):", "50000");
                    if (funds && !isNaN(Number(funds))) {
                      setDealerWallet((w) => w + Number(funds));
                    }
                  }}
                />
                <DealerRequirements requirements={requirements} />
              </>
            )}
            {tab === "chat" && (
              <ChatsView chats={chats} onOpenChat={setActiveChat} />
            )}
            {tab === "profile" && (
              <ProfileView role="dealer" onLogoutToggle={handleToggleRole} />
            )}
          </>
        )}
      </main>

      {/* Floating Action Button (FAB) */}
      {role === "farmer" ? (
        <button className="fab" onClick={() => setCreating(true)}>
          <Plus size={20} /> List produce
        </button>
      ) : tab === "requirements" ? (
        <button className="fab" onClick={() => setPostingReq(true)}>
          <Plus size={20} /> Post Requirement
        </button>
      ) : null}

      {/* Bottom Navigation tabs */}
      <nav className="tabs" aria-label="Primary">
        {tabsConfig.map((t) =>
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

      {/* Overlays & Sheets */}
      {creating && (
        <CreateListing onClose={() => setCreating(false)} onPublish={handlePublishListing} />
      )}

      {postingReq && (
        <CreateRequirement onClose={() => setPostingReq(false)} onPublish={handlePublishRequirement} />
      )}

      {selectedListing && (
        <ListingDetailsDrawer
          l={selectedListing}
          role={role}
          activities={activities}
          onClose={() => setSelectedListing(null)}
          onAcceptOffer={handleAcceptOffer}
          onSubmitOffer={handleDealerSubmitOffer}
          onOpenChat={handleOpenChat}
        />
      )}

      {activeChat && (
        <ChatOverlay
          thread={activeChat}
          role={role}
          onClose={() => setActiveChat(null)}
          onSendMessage={handleSendMessage}
        />
      )}
    </div>
  );
}
