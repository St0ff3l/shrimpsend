'use client';

import { useRef, type ReactNode } from 'react';
import { useVirtualizer } from '@tanstack/react-virtual';

type VirtualizedDeviceRowsProps = {
  count: number;
  estimateRowHeight?: number;
  getItemKey: (index: number) => string | number;
  className?: string;
  innerClassName?: string;
  renderRow: (index: number) => ReactNode;
};

/**
 * Virtualized vertical list for many device rows (sends targets, device management).
 */
export function VirtualizedDeviceRows({
  count,
  estimateRowHeight = 96,
  getItemKey,
  className,
  innerClassName,
  renderRow,
}: VirtualizedDeviceRowsProps) {
  const parentRef = useRef<HTMLDivElement>(null);
  // eslint-disable-next-line react-hooks/incompatible-library -- TanStack Virtual
  const virtualizer = useVirtualizer({
    count,
    getScrollElement: () => parentRef.current,
    estimateSize: () => estimateRowHeight,
    overscan: 8,
    getItemKey,
  });

  return (
    <div
      ref={parentRef}
      role="list"
      className={className ?? 'min-h-0 flex-1 overflow-y-auto overscroll-contain'}
    >
      <div
        className={innerClassName ?? 'relative w-full'}
        style={{ height: virtualizer.getTotalSize() }}
      >
        {virtualizer.getVirtualItems().map((vi) => (
          <div
            key={vi.key}
            role="listitem"
            data-index={vi.index}
            ref={virtualizer.measureElement}
            className="absolute left-0 top-0 w-full px-0 py-0.5"
            style={{ transform: `translateY(${vi.start}px)` }}
          >
            {renderRow(vi.index)}
          </div>
        ))}
      </div>
    </div>
  );
}
