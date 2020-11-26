//
//  MBTableGridVirtualString.m
//  MBTableGrid
//
//  Created by Evan Miller on 1/17/20.
//

#import "MBTableGridVirtualString.h"
#import "MBTableGrid.h"

#define _row(cellIndex, rows, cols) ((cellIndex) % (rows) + (cols-cols))
#define _col(cellIndex, rows, cols) ((cellIndex) / (rows) + (cols-cols))

@interface MBTableGrid (Private)

@property (nonatomic, readonly) BOOL _shouldAbortFindOperation;

- (id)_objectValueForColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;

@end

@implementation MBTableGridVirtualString

/* This is a virtual string that treats cells as individual "characters" that can be searched
 * by an instance of NSTextFinder. For details see:
 *
 * https://github.com/pixelspark/mbtablegrid/issues/31
 *
 * Searches in column-first order.
 */

- (instancetype)initWithTableGrid:(MBTableGrid *)tableGrid {
    if (self = [super init]) {
        _tableGrid = tableGrid;
    }
    return self;
}

- (NSUInteger)length {
    return _tableGrid.numberOfRows * _tableGrid.numberOfColumns;
}

- (NSRange)rangeOfString:(NSString *)searchString options:(NSStringCompareOptions)mask range:(NSRange)rangeOfReceiverToSearch {
    NSUInteger cellIndex = rangeOfReceiverToSearch.location;
    
    NSInteger rowCount = _tableGrid.numberOfRows;
    NSInteger columnCount = _tableGrid.numberOfColumns;
    
    while (cellIndex < rangeOfReceiverToSearch.location + rangeOfReceiverToSearch.length) {
        NSRange result = NSMakeRange(NSNotFound, 0);
        NSUInteger rowIndex = _row(cellIndex, rowCount, columnCount);
        NSUInteger columnIndex = _col(cellIndex, rowCount, columnCount);
        
        @autoreleasepool {
            NSString *value = [_tableGrid _objectValueForColumn:columnIndex row:rowIndex];
            if (value) {
                result = [value rangeOfString:searchString options:mask];
            }
        }
        
        if (result.location != NSNotFound) {
            return NSMakeRange(cellIndex, 1);
        }
        
        /* Checking whether to abort is expensive (requires access to main thread),
         * so don't do it too often */
        if ((cellIndex % 1000) == 0 && _tableGrid._shouldAbortFindOperation)
            break;
        
        cellIndex++;
    }
    return NSMakeRange(NSNotFound, 0);
}

@end
