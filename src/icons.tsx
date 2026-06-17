import type { SVGProps } from "react";

type P = SVGProps<SVGSVGElement> & { size?: number };

const base = (size: number): SVGProps<SVGSVGElement> => ({
  width: size,
  height: size,
  viewBox: "0 0 24 24",
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 1.75,
  strokeLinecap: "round",
  strokeLinejoin: "round",
  "aria-hidden": true,
});

export const Home = ({ size = 24, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="M3 10.5 12 3l9 7.5" />
    <path d="M5 9.5V20a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V9.5" />
    <path d="M9.5 21v-6h5v6" />
  </svg>
);

export const Search = ({ size = 24, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <circle cx="11" cy="11" r="7" />
    <path d="m20 20-3.5-3.5" />
  </svg>
);

export const Chat = ({ size = 24, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="M21 11.5a8 8 0 0 1-11.6 7.1L3 20.5l1.9-5.4A8 8 0 1 1 21 11.5Z" />
  </svg>
);

export const Wallet = ({ size = 24, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="M3 7.5A2.5 2.5 0 0 1 5.5 5H18a1 1 0 0 1 1 1v1" />
    <rect x="3" y="7" width="18" height="13" rx="2.5" />
    <path d="M16 13h2.5" />
  </svg>
);

export const User = ({ size = 24, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <circle cx="12" cy="8" r="4" />
    <path d="M4.5 20a7.5 7.5 0 0 1 15 0" />
  </svg>
);

export const Plus = ({ size = 24, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="M12 5v14M5 12h14" />
  </svg>
);

export const Bell = ({ size = 24, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="M6 9a6 6 0 0 1 12 0c0 5 2 6 2 6H4s2-1 2-6Z" />
    <path d="M10 20a2 2 0 0 0 4 0" />
  </svg>
);

export const Check = ({ size = 24, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="m4 12.5 5 5L20 6.5" />
  </svg>
);

export const Verified = ({ size = 24, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="m9 12 2 2 4-4" />
    <path d="M12 2.5 14.6 5l3.5-.2.4 3.5L21 12l-2.5 2.6.2 3.5-3.5.4L12 21.5 9.4 19l-3.5.2-.4-3.5L3 12l2.5-2.6L5.3 5.9l3.5-.4L12 2.5Z" />
  </svg>
);

export const Clock = ({ size = 24, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <circle cx="12" cy="12" r="8.5" />
    <path d="M12 7.5V12l3 2" />
  </svg>
);

export const Alert = ({ size = 24, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="M12 3.5 21 19H3l9-15.5Z" />
    <path d="M12 10v4M12 17h.01" />
  </svg>
);

export const ChevronRight = ({ size = 24, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="m9 5 7 7-7 7" />
  </svg>
);

export const ChevronLeft = ({ size = 24, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="m15 5-7 7 7 7" />
  </svg>
);

export const Camera = ({ size = 24, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="M4 8.5A1.5 1.5 0 0 1 5.5 7h2L9 5h6l1.5 2h2A1.5 1.5 0 0 1 20 8.5v9A1.5 1.5 0 0 1 18.5 19h-13A1.5 1.5 0 0 1 4 17.5Z" />
    <circle cx="12" cy="13" r="3.5" />
  </svg>
);

export const Pin = ({ size = 24, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="M12 21s7-5.6 7-11a7 7 0 1 0-14 0c0 5.4 7 11 7 11Z" />
    <circle cx="12" cy="10" r="2.5" />
  </svg>
);

export const Up = ({ size = 24, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="M12 19V5M6 11l6-6 6 6" />
  </svg>
);

export const Down = ({ size = 24, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="M12 5v14M6 13l6 6 6-6" />
  </svg>
);

export const X = ({ size = 24, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="M6 6l12 12M18 6 6 18" />
  </svg>
);

export const Mic = ({ size = 24, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <rect x="9" y="3" width="6" height="11" rx="3" />
    <path d="M5 11a7 7 0 0 0 14 0M12 18v3" />
  </svg>
);

export const Leaf = ({ size = 24, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="M5 19c0-9 6-13 14-13 0 8-4 14-13 14a6 6 0 0 1-1-1Z" />
    <path d="M5 19c2.5-3 5.5-5 9-6.5" />
  </svg>
);

export const Eye = ({ size = 24, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12Z" />
    <circle cx="12" cy="12" r="3" />
  </svg>
);

export const Tag = ({ size = 24, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="M3 12V4a1 1 0 0 1 1-1h8l9 9-9 9-9-9Z" />
    <circle cx="7.5" cy="7.5" r="1.4" />
  </svg>
);
