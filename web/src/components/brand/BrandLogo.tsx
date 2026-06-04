import Image from 'next/image';
import { BRAND_LOGO_IOS_RADIUS_CLASS, BRAND_LOGO_SRC } from '@/lib/brandAssets';
import { cn } from '@/lib/utils';

type BrandLogoProps = {
  size: number;
  alt: string;
  className?: string;
  priority?: boolean;
};

/** 品牌 Logo：正方形素材 + iOS 圆角；ring/shadow 加在外层圆角容器上。 */
export function BrandLogo({ size, alt, className, priority }: BrandLogoProps) {
  return (
    <span
      className={cn(
        'relative inline-block shrink-0 overflow-hidden',
        BRAND_LOGO_IOS_RADIUS_CLASS,
        className,
      )}
      style={{ width: size, height: size }}
    >
      <Image
        src={BRAND_LOGO_SRC}
        alt={alt}
        fill
        priority={priority}
        sizes={`${size}px`}
        className="object-cover"
      />
    </span>
  );
}
