import { useEffect, useRef, useState } from "react";
import {
  Check,
  ChevronLeft,
  X,
} from "./icons";
import { cropCatalog, inr, type BuyRequirement, type Grade } from "./data";

type Unit = "kg" | "quintal" | "ton";

const STEPS = ["Crop & Quality", "Qty & Budget", "Review"];

interface CreateRequirementProps {
  onClose: () => void;
  onPublish: (req: Omit<BuyRequirement, "id" | "dealerName">) => void;
}

export default function CreateRequirement({ onClose, onPublish }: CreateRequirementProps) {
  const [step, setStep] = useState(0);
  const [crop, setCrop] = useState<(typeof cropCatalog)[number] | null>(null);
  const [qty, setQty] = useState("");
  const [unit, setUnit] = useState<Unit>("ton");
  const [grade, setGrade] = useState<Grade>("A");
  const [maxPrice, setMaxPrice] = useState("");
  const [location, setLocation] = useState("Kolar APMC");
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

  const canNext = [
    !!crop,
    qty.trim() !== "" && Number(qty) > 0 && maxPrice.trim() !== "" && Number(maxPrice) > 0,
    true,
  ][step];

  const last = step === STEPS.length - 1;

  const next = () => {
    if (last) {
      if (crop) {
        onPublish({
          crop: crop.crop,
          emoji: crop.emoji,
          qty: Number(qty),
          unit,
          grade,
          maxPrice: Number(maxPrice),
          location,
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

  return (
    <>
      <div className="backdrop" onClick={onClose} />
      <section className="sheet" role="dialog" aria-modal="true" aria-label="Post Buy Requirement">
        {done ? (
          <Success crop={crop?.crop ?? "produce"} onClose={onClose} />
        ) : (
          <>
            <div className="sheet__head">
              <button className="iconbtn" style={{ color: "var(--ink)", marginInline: -8 }} onClick={back} aria-label={step === 0 ? "Close" : "Back"}>
                {step === 0 ? <X size={22} /> : <ChevronLeft size={22} />}
              </button>
              <span className="sheet__title">Post Buy Requirement</span>
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
                  <h2 className="step__q">What crop do you need?</h2>
                  <p className="step__hint">Select from our catalog of standard mandis crops.</p>
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

                  <h3 className="field__label" style={{ marginTop: 24, marginBottom: 8 }}>Minimum Grade Required</h3>
                  <div className="qtyrow" style={{ display: "flex", gap: 8 }}>
                    {(["A", "B", "C"] as Grade[]).map((g) => (
                      <button
                        key={g}
                        className={`chip ${grade === g ? "chip--active" : ""}`}
                        style={{ flex: 1, paddingBlock: 10, justifyContent: "center", borderRadius: "8px" }}
                        onClick={() => setGrade(g)}
                      >
                        Grade {g}
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {step === 1 && (
                <div className="reveal">
                  <h2 className="step__q">Define qty and budget</h2>
                  <p className="step__hint">Specify requirements so matching farmers can contact you.</p>
                  
                  <div className="field">
                    <label className="field__label" htmlFor="qty">
                      Desired Quantity <span className="req">*</span>
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
                    <label className="field__label" htmlFor="maxPrice">
                      Max Budget (₹/quintal) <span className="req">*</span>
                    </label>
                    <input
                      id="maxPrice"
                      className="input num"
                      placeholder="e.g. 2500"
                      value={maxPrice}
                      onChange={(e) => setMaxPrice(e.target.value)}
                    />
                    <p className="step__hint" style={{ marginTop: 8, marginBottom: 0 }}>
                      Mandi reference rate for {crop?.crop}: <b>{inr(crop?.market || 0)}</b>/quintal.
                    </p>
                  </div>

                  <div className="field">
                    <label className="field__label" htmlFor="loc">
                      Fulfillment Location
                    </label>
                    <input
                      id="loc"
                      className="input"
                      value={location}
                      onChange={(e) => setLocation(e.target.value)}
                    />
                  </div>
                </div>
              )}

              {step === 2 && (
                <div className="reveal">
                  <h2 className="step__q">Confirm &amp; Post</h2>
                  <p className="step__hint">Check details before making your request visible to farmers.</p>
                  <div className="review">
                    <Row k="Crop Needed" v={`${crop?.emoji} ${crop?.crop}`} />
                    <Row k="Quantity" v={`${qty || "—"} ${unit}`} />
                    <Row k="Grade Limit" v={`Grade ${grade}`} />
                    <Row k="Max Budget" v={maxPrice ? `${inr(Number(maxPrice))}/quintal` : "—"} />
                    <Row k="Delivery Point" v={location} />
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
                {last ? "Post Requirement" : "Continue"}
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
      <h2 className="done__title">Requirement Posted</h2>
      <p className="done__sub">
        Farmers near Kolar can now see your requirement for {crop} and contact you directly.
      </p>
      <div style={{ display: "flex", gap: 12, marginTop: 28, width: "100%" }}>
        <button className="btn btn--primary" onClick={onClose} style={{ width: "100%" }}>
          Done
        </button>
      </div>
    </div>
  );
}
