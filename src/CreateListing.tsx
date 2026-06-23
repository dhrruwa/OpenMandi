import { useEffect, useMemo, useRef, useState } from "react";
import {
  Camera,
  Check,
  ChevronLeft,
  Leaf,
  Mic,
  Verified,
  X,
} from "./icons";
import { cropCatalog, inr } from "./data";

type Grade = "A" | "B" | "C";
type Unit = "kg" | "quintal" | "ton";

const GRADES: { g: Grade; label: string; desc: string }[] = [
  { g: "A", label: "Grade A", desc: "Premium · uniform, fresh, export-ready" },
  { g: "B", label: "Grade B", desc: "Good · minor blemishes, local market" },
  { g: "C", label: "Grade C", desc: "Fair · processing, bulk use" },
];

const STEPS = ["Crop", "Quantity", "Quality", "Photos", "Price", "Review"];

export default function CreateListing({
  onClose,
  onPublish,
}: {
  onClose: () => void;
  onPublish: (listing: {
    crop: string;
    emoji: string;
    qty: number;
    unit: string;
    grade: Grade;
    organic: boolean;
    price: number;
    marketPrice: number;
    harvestIn: number;
    location: string;
  }) => void;
}) {
  const [step, setStep] = useState(0);
  const [crop, setCrop] = useState<(typeof cropCatalog)[number] | null>(null);
  const [qty, setQty] = useState("");
  const [unit, setUnit] = useState<Unit>("quintal");
  const [harvest, setHarvest] = useState("");
  const [grade, setGrade] = useState<Grade | null>(null);
  const [organic, setOrganic] = useState(false);
  const [photos, setPhotos] = useState<string[]>([]);
  const [price, setPrice] = useState("");
  const [done, setDone] = useState(false);
  const bodyRef = useRef<HTMLDivElement>(null);

  // lock background scroll while sheet open
  useEffect(() => {
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = prev;
    };
  }, []);

  // scroll body to top on step change
  useEffect(() => {
    bodyRef.current?.scrollTo({ top: 0 });
  }, [step]);

  const market = crop?.market ?? 0;
  const priceNum = Number(price) || 0;
  const verdict = useMemo(() => {
    if (!priceNum || !market) return null;
    const diff = (priceNum - market) / market;
    if (diff > 0.12) return "high" as const;
    if (diff < -0.08) return "low" as const;
    return "fair" as const;
  }, [priceNum, market]);

  const canNext = [
    !!crop,
    qty.trim() !== "" && Number(qty) > 0 && harvest.trim() !== "",
    !!grade,
    true, // photos optional but encouraged
    priceNum > 0,
    true,
  ][step];

  const last = step === STEPS.length - 1;

  const next = () => {
    if (last) {
      if (crop && grade) {
        const harvestDays = harvest
          ? Math.max(0, Math.ceil((new Date(harvest).getTime() - new Date().getTime()) / (1000 * 3600 * 24)))
          : 0;
        onPublish({
          crop: crop.crop,
          emoji: crop.emoji,
          qty: Number(qty) || 0,
          unit,
          grade,
          organic,
          price: Number(price) || 0,
          marketPrice: crop.market,
          harvestIn: harvestDays,
          location: "Kolar",
        });
      }
      setDone(true);
      return;
    }
    setStep((s) => Math.min(s + 1, STEPS.length - 1));
  };
  const back = () => {
    if (step === 0) return onClose();
    setStep((s) => s - 1);
  };

  const addPhoto = () =>
    setPhotos((p) => (p.length >= 3 ? p : [...p, crop?.emoji ?? "📷"]));

  return (
    <>
      <div className="backdrop" onClick={onClose} />
      <section className="sheet" role="dialog" aria-modal="true" aria-label="List your produce">
        {done ? (
          <Success crop={crop?.crop ?? "produce"} onClose={onClose} />
        ) : (
          <>
            <div className="sheet__head">
              <button className="iconbtn" style={{ color: "var(--ink)", marginInline: -8 }} onClick={back} aria-label={step === 0 ? "Close" : "Back"}>
                {step === 0 ? <X size={22} /> : <ChevronLeft size={22} />}
              </button>
              <span className="sheet__title">List your produce</span>
              <span className="sheet__step num">
                {step + 1}/{STEPS.length}
              </span>
            </div>
            <div className="sheet__progress" aria-hidden>
              <i style={{ transform: `scaleX(${(step + 1) / STEPS.length})` }} />
            </div>

            <div className="sheet__body" ref={bodyRef}>
              {step === 0 && (
                <div className="reveal">
                  <h2 className="step__q">What are you selling?</h2>
                  <p className="step__hint">Pick your crop. Tap the mic to say it aloud.</p>
                  <button className="voice">
                    <Mic size={18} /> Say crop name
                  </button>
                  <div className="cropgrid" style={{ marginTop: 12 }}>
                    {cropCatalog.map((c) => (
                      <button
                        key={c.crop}
                        className={`cropbtn ${crop?.crop === c.crop ? "cropbtn--on" : ""}`}
                        aria-pressed={crop?.crop === c.crop}
                        onClick={() => setCrop(c)}
                      >
                        <span aria-hidden>{c.emoji}</span>
                        <span>{c.crop}</span>
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {step === 1 && (
                <div className="reveal">
                  <h2 className="step__q">How much, and when?</h2>
                  <p className="step__hint">
                    {crop?.emoji} {crop?.crop} — buyers filter by quantity, so be exact.
                  </p>
                  <div className="field">
                    <label className="field__label" htmlFor="qty">
                      Quantity <span className="req">*</span>
                    </label>
                    <div className="qtyrow">
                      <input
                        id="qty"
                        className="input num"
                        inputMode="decimal"
                        placeholder="0"
                        value={qty}
                        onChange={(e) => setQty(e.target.value)}
                      />
                      <div className="unitsel" role="group" aria-label="Unit">
                        {(["kg", "quintal", "ton"] as Unit[]).map((u) => (
                          <button
                            key={u}
                            aria-pressed={unit === u}
                            onClick={() => setUnit(u)}
                          >
                            {u}
                          </button>
                        ))}
                      </div>
                    </div>
                  </div>
                  <div className="field">
                    <label className="field__label" htmlFor="harvest">
                      Ready by <span className="req">*</span>
                    </label>
                    <input
                      id="harvest"
                      className="input"
                      type="date"
                      value={harvest}
                      onChange={(e) => setHarvest(e.target.value)}
                    />
                    <p className="step__hint" style={{ marginTop: 8, marginBottom: 0 }}>
                      Already harvested? Pick today.
                    </p>
                  </div>
                </div>
              )}

              {step === 2 && (
                <div className="reveal">
                  <h2 className="step__q">What quality grade?</h2>
                  <p className="step__hint">Honest grading earns repeat buyers and better ratings.</p>
                  <div className="grades">
                    {GRADES.map((x) => (
                      <button
                        key={x.g}
                        className={`gradebtn ${grade === x.g ? "gradebtn--on" : ""}`}
                        aria-pressed={grade === x.g}
                        onClick={() => setGrade(x.g)}
                        style={{ gridColumn: "1 / -1" }}
                      >
                        <b>{x.label}</b>
                        <small>{x.desc}</small>
                      </button>
                    ))}
                  </div>
                  <button
                    className="toggle"
                    aria-pressed={organic}
                    onClick={() => setOrganic((o) => !o)}
                    style={{ marginTop: 16 }}
                  >
                    <span style={{ color: "var(--ok)" }}>
                      <Leaf size={22} />
                    </span>
                    <span className="toggle__txt">
                      <b>Organic / chemical-free</b>
                      <small>Adds a verified-organic badge buyers can filter for</small>
                    </span>
                    <span className="switch" aria-hidden />
                  </button>
                </div>
              )}

              {step === 3 && (
                <div className="reveal">
                  <h2 className="step__q">Add photos</h2>
                  <p className="step__hint">
                    Listings with photos get ~3× more offers. Show the real produce.
                  </p>
                  <div className="photos">
                    {photos.map((p, i) => (
                      <div className="photo" key={i}>
                        <span aria-hidden>{p}</span>
                        <button
                          className="photo__rm"
                          aria-label="Remove photo"
                          onClick={() => setPhotos((ps) => ps.filter((_, j) => j !== i))}
                        >
                          <X size={14} />
                        </button>
                      </div>
                    ))}
                    {photos.length < 3 && (
                      <button className="photoadd" onClick={addPhoto}>
                        <Camera size={26} />
                        Add photo
                      </button>
                    )}
                  </div>
                </div>
              )}

              {step === 4 && (
                <div className="reveal">
                  <h2 className="step__q">Set your price</h2>
                  <p className="step__hint">See today's mandi price first, then decide.</p>
                  <div className="market">
                    <div className="market__head">
                      <Verified size={14} /> TODAY'S MANDI PRICE · {crop?.crop?.toUpperCase()}
                    </div>
                    <div className="market__val num">
                      {inr(market)} <span className="card__per">/quintal</span>
                    </div>
                    <div className="market__src">Source: eNAM / Agmarknet · Kolar APMC</div>
                  </div>
                  <div className="field">
                    <label className="field__label" htmlFor="price">
                      Your asking price (₹/quintal) <span className="req">*</span>
                    </label>
                    <input
                      id="price"
                      className="input num"
                      inputMode="numeric"
                      placeholder={String(market)}
                      value={price}
                      onChange={(e) => setPrice(e.target.value)}
                    />
                    {verdict && (
                      <div className={`priceverdict priceverdict--${verdict}`}>
                        {verdict === "fair" && <><Check size={16} /> Fair — close to today's mandi rate</>}
                        {verdict === "high" && <>▲ Above mandi — may take longer to sell</>}
                        {verdict === "low" && <>▼ Below mandi — you could ask for more</>}
                      </div>
                    )}
                  </div>
                </div>
              )}

              {step === 5 && (
                <div className="reveal">
                  <h2 className="step__q">Review &amp; publish</h2>
                  <p className="step__hint">Check the details. You can edit anything before going live.</p>
                  <div className="review">
                    <Row k="Crop" v={`${crop?.emoji} ${crop?.crop}`} />
                    <Row k="Quantity" v={`${qty || "—"} ${unit}`} />
                    <Row k="Ready by" v={harvest || "—"} />
                    <Row k="Grade" v={grade ? `Grade ${grade}` : "—"} />
                    <Row k="Organic" v={organic ? "Yes" : "No"} />
                    <Row k="Photos" v={`${photos.length} added`} />
                    <Row k="Asking price" v={priceNum ? `${inr(priceNum)}/quintal` : "—"} />
                  </div>
                  <div className="trust">
                    <Verified size={18} />
                    <span>
                      Payment is held in escrow and released to you only after the buyer
                      confirms delivery — so you always get paid.
                    </span>
                  </div>
                </div>
              )}
            </div>

            <div className="sheet__foot">
              {step > 0 && (
                <button className="btn btn--ghost" onClick={back}>
                  Back
                </button>
              )}
              <button
                className={`btn ${last ? "btn--accent" : "btn--primary"}`}
                disabled={!canNext}
                onClick={next}
              >
                {last ? "Publish listing" : "Continue"}
              </button>
            </div>
          </>
        )}
      </section>
    </>
  );
}

function Row({ k, v }: { k: string; v: string }) {
  return (
    <div className="review__row">
      <span className="review__k">{k}</span>
      <span className="review__v">{v}</span>
    </div>
  );
}

function Success({ crop, onClose }: { crop: string; onClose: () => void }) {
  return (
    <div className="done">
      <div className="done__ring">
        <Check size={42} />
      </div>
      <h2 className="done__title">Your {crop} is live</h2>
      <p className="done__sub">
        Buyers near Kolar can see it now. We'll notify you the moment an offer comes in.
      </p>
      <div style={{ display: "flex", gap: 12, marginTop: 28, width: "100%" }}>
        <button className="btn btn--primary" onClick={onClose}>
          Done
        </button>
      </div>
    </div>
  );
}
