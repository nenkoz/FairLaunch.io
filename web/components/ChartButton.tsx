interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
    children: React.ReactNode;
    className?: string;
    variant?: string;
}

export default function ChartButton({ children, className, variant, ...props }: ButtonProps) {
    return (
        <button className={`bg-white border border-gray-300 rounded px-3 py-1 hover:bg-gray-100 text-gray-800 ${className}`} {...props}>
            {children}
        </button>
    );
}
