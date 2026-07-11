import React from 'react';
import { motion, HTMLMotionProps } from 'motion/react';
import { ChevronLeft } from 'lucide-react';
import { useNavigate } from 'react-router';

//
// Typography
//
export function Heading1({ children, className = '', ...props }: React.HTMLAttributes<HTMLHeadingElement>) {
  return <h1 className={`text-foreground font-medium text-3xl tracking-tight font-serif ${className}`} style={{ fontFamily: "'Merriweather', serif" }} {...props}>{children}</h1>;
}

export function Heading2({ children, className = '', ...props }: React.HTMLAttributes<HTMLHeadingElement>) {
  return <h2 className={`text-foreground font-medium text-2xl tracking-tight font-serif ${className}`} style={{ fontFamily: "'Merriweather', serif" }} {...props}>{children}</h2>;
}

export function Heading3({ children, className = '', ...props }: React.HTMLAttributes<HTMLHeadingElement>) {
  return <h3 className={`text-foreground font-medium text-xl font-serif ${className}`} style={{ fontFamily: "'Merriweather', serif" }} {...props}>{children}</h3>;
}

export function Text({ children, className = '', ...props }: React.HTMLAttributes<HTMLParagraphElement>) {
  return <p className={`text-muted-foreground text-base font-sans ${className}`} style={{ fontFamily: "'Inter', sans-serif" }} {...props}>{children}</p>;
}

export function SmallText({ children, className = '', ...props }: React.HTMLAttributes<HTMLParagraphElement>) {
  return <p className={`text-muted-foreground text-sm font-sans ${className}`} style={{ fontFamily: "'Inter', sans-serif" }} {...props}>{children}</p>;
}

//
// Layout & Surfaces
//
export function PageContainer({ children, className = '', ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div className={`min-h-full bg-background dark:bg-background px-4 pt-6 pb-24 ${className}`} {...props}>
      {children}
    </div>
  );
}

export function AppBar({ title, onBack, rightAction }: { title?: string, onBack?: () => void, rightAction?: React.ReactNode }) {
  const navigate = useNavigate();
  return (
    <div className="sticky top-0 z-40 bg-background/90 backdrop-blur-xl border-b border-border px-4 py-3 flex items-center justify-between shadow-sm">
      <button onClick={onBack || (() => navigate(-1))} className="text-primary active:scale-95 transition-transform p-2 -ml-2 rounded-full hover:bg-muted">
        <ChevronLeft size={24} />
      </button>
      {title && <h2 className="text-foreground font-semibold font-sans text-base">{title}</h2>}
      <div className="w-10 flex justify-end">
        {rightAction}
      </div>
    </div>
  );
}

//
// Cards
//
export function Card({ children, className = '', onClick, ...props }: HTMLMotionProps<"div">) {
  const Component = onClick ? motion.button : motion.div;
  return (
    <Component
      whileTap={onClick ? { scale: 0.98 } : undefined}
      onClick={onClick as any}
      className={`w-full bg-card rounded-2xl p-5 shadow-sm border border-border text-left ${className}`}
      {...props}
    >
      {children}
    </Component>
  );
}

export function PrimaryCard({ children, className = '', ...props }: HTMLMotionProps<"div">) {
  return (
    <motion.div
      className={`bg-primary rounded-2xl p-6 shadow-lg text-primary-foreground ${className}`}
      {...props}
    >
      {children}
    </motion.div>
  );
}

export function HeroCard({ title, subtitle, icon: Icon, children, className = '' }: any) {
  return (
    <PrimaryCard className={`relative overflow-hidden ${className}`}>
      <div className="absolute top-0 right-0 p-6 opacity-10">
        <Icon size={120} />
      </div>
      <div className="relative z-10">
        <div className="flex items-center gap-2 mb-3">
          <div className="w-8 h-8 rounded-full bg-white/20 flex items-center justify-center">
            <Icon size={16} className="text-white" />
          </div>
          <div>
            <h3 className="text-white font-semibold font-sans text-sm">{title}</h3>
            {subtitle && <p className="text-white/80 font-sans text-xs">{subtitle}</p>}
          </div>
        </div>
        {children}
      </div>
    </PrimaryCard>
  );
}

//
// Buttons
//
export function PrimaryButton({ children, className = '', ...props }: HTMLMotionProps<"button">) {
  return (
    <motion.button
      whileTap={{ scale: 0.97 }}
      className={`bg-primary text-primary-foreground w-full py-3.5 rounded-xl font-medium shadow-md shadow-primary/20 font-sans text-base ${className}`}
      {...props}
    >
      {children}
    </motion.button>
  );
}

export function SecondaryButton({ children, className = '', ...props }: HTMLMotionProps<"button">) {
  return (
    <motion.button
      whileTap={{ scale: 0.97 }}
      className={`bg-accent text-accent-foreground w-full py-3.5 rounded-xl font-medium shadow-md shadow-accent/20 font-sans text-base ${className}`}
      {...props}
    >
      {children}
    </motion.button>
  );
}

export function OutlinedButton({ children, className = '', ...props }: HTMLMotionProps<"button">) {
  return (
    <motion.button
      whileTap={{ scale: 0.97 }}
      className={`border-2 border-primary/20 text-primary hover:bg-primary/5 w-full py-3 rounded-xl font-medium font-sans text-base ${className}`}
      {...props}
    >
      {children}
    </motion.button>
  );
}

export function IconButton({ icon: Icon, active = false, className = '', ...props }: any) {
  return (
    <motion.button
      whileTap={{ scale: 0.9 }}
      className={`w-12 h-12 rounded-full flex items-center justify-center transition-all ${
        active 
          ? 'bg-primary text-primary-foreground shadow-lg shadow-primary/30' 
          : 'bg-muted text-primary hover:bg-primary/10'
      } ${className}`}
      {...props}
    >
      <Icon size={20} />
    </motion.button>
  );
}

//
// Lists & Rows
//
export function SettingsRow({ icon: Icon, label, sublabel, rightAction, onClick, className = '' }: any) {
  return (
    <motion.div
      whileTap={{ scale: 0.98 }}
      onClick={onClick}
      className={`w-full flex items-center gap-4 py-4 transition-colors hover:bg-muted/50 text-left cursor-pointer ${className}`}
    >
      <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center flex-shrink-0">
        <Icon size={20} className="text-primary" />
      </div>
      <div className="flex-1">
        <h3 className="text-foreground font-semibold font-sans text-sm mb-0.5">{label}</h3>
        {sublabel && <p className="text-muted-foreground font-sans text-xs">{sublabel}</p>}
      </div>
      {rightAction}
    </motion.div>
  );
}

export function SectionHeader({ title, action, className = '' }: any) {
  return (
    <div className={`flex items-center justify-between mb-4 ${className}`}>
      <h2 className="text-foreground font-semibold font-sans text-lg tracking-tight">{title}</h2>
      {action && <button className="text-accent font-medium text-sm hover:underline">{action}</button>}
    </div>
  );
}

//
// Chips
//
export function Chip({ active, children, onClick, className = '' }: any) {
  return (
    <motion.button
      whileTap={{ scale: 0.95 }}
      onClick={onClick}
      className={`px-4 py-2 rounded-full font-sans text-sm font-medium transition-all ${
        active 
          ? 'bg-primary text-primary-foreground shadow-md' 
          : 'bg-card text-foreground border border-border hover:bg-muted'
      } ${className}`}
    >
      {children}
    </motion.button>
  );
}
