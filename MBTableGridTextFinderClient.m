//
//  MBTableGridTextFinderClient.m
//  MBTableGrid
//
//  Created by Evan Miller on 1/17/20.
//

#import "MBTableGridTextFinderClient.h"
#import "MBTableGridVirtualString.h"
#import "MBTableGrid.h"
#import "MBTableGridContentView.h"

@interface MBTableGrid ()
- (NSCell *)_cellForColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (id)_objectValueForColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (void)_setObjectValue:(id)value forColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (BOOL)_canEditCellAtColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (void)scrollToArea:(NSRect)area animate:(BOOL)animate;
@end

@implementation MBTableGridTextFinderClient

// Pros and cons of string vs stringAtIndex:effectiveRange:endsWithSearchBoundary
// - the returned `string` can be subclassed - i.e. do a search without creating any substrings
// - `string` can be cancelled inside of rangeOfString:options: (read a value and return NSNotFound)
// - `stringAtIndex:` crashes with 10s of thousands of substrings - AppKit bug
// - BUT `string` searches are on the main thread, whereas stringAtIndex: gets kicked off to worker threads
// - So `string` looks faster and more stable overall - at the cost of pinning the UI on large tables. Sigh.
#define _row(cellIndex, rows, cols) ((cellIndex) % (rows) + (cols-cols))
#define _col(cellIndex, rows, cols) ((cellIndex) / (rows) + (cols-cols))
#define _cell(rowIndex, columnIndex, rowCount, columCount) ((columnIndex) * (rowCount) + (rowIndex) + (columnCount-columnCount))

- (id)initWithTableGrid:(MBTableGrid *)tableGrid {
    if (self = [super init]) {
        _tableGrid = tableGrid;
    }
    return self;
}

- (NSString *)string {
    return [[MBTableGridVirtualString alloc] initWithTableGrid:_tableGrid];
}

- (NSRange)firstSelectedRange {
    NSUInteger columnCount = _tableGrid.numberOfColumns;
    NSUInteger rowCount = _tableGrid.numberOfRows;
    NSUInteger rowIndex = 0, columnIndex = 0;

    if (_tableGrid.selectedRowIndexes)
        rowIndex = _tableGrid.selectedRowIndexes.firstIndex;

    if (_tableGrid.selectedColumnIndexes)
        columnIndex = _tableGrid.selectedColumnIndexes.firstIndex;
        
    NSUInteger cellIndex = _cell(rowIndex, columnIndex, rowCount, columnCount);

    return NSMakeRange(cellIndex, 1);
}

- (NSArray<NSValue *> *)selectedRanges {
    NSUInteger columnCount = _tableGrid.numberOfColumns;
    NSUInteger rowCount = _tableGrid.numberOfRows;
    
    if (rowCount == 0 || columnCount == 0)
        return @[];
    
    if (!_tableGrid.selectedRowIndexes && !_tableGrid.selectedColumnIndexes)
        return @[];
    
    NSMutableArray<NSValue *> *ranges = [NSMutableArray array];
    NSUInteger minRow = 0, maxRow = rowCount-1;
    NSUInteger minCol = 0, maxCol = columnCount-1;
    
    if (_tableGrid.selectedColumnIndexes) {
        minCol = _tableGrid.selectedColumnIndexes.firstIndex;
        maxCol = _tableGrid.selectedColumnIndexes.lastIndex;
    }

    if (_tableGrid.selectedRowIndexes) {
        minRow = _tableGrid.selectedRowIndexes.firstIndex;
        maxRow = _tableGrid.selectedRowIndexes.lastIndex;
    }
    
    for (NSUInteger j=minCol; j<=maxCol; j++) {
        NSUInteger cellIndex = _cell(minRow, j, rowCount, columnCount);
        NSRange range = NSMakeRange(cellIndex, (maxRow - minRow + 1));
        [ranges addObject:[NSValue valueWithRange:range]];
    }
    
    return ranges;
}

- (void)setSelectedRanges:(NSArray<NSValue *> *)selectedRanges {
    NSUInteger columnCount = _tableGrid.numberOfColumns;
    NSUInteger rowCount = _tableGrid.numberOfRows;
    
    if (selectedRanges.count) {
        NSUInteger cellIndex = selectedRanges.firstObject.rangeValue.location;
        NSUInteger rowIndex = _row(cellIndex, rowCount, columnCount);
        NSUInteger filteredIndex = _col(cellIndex, rowCount, columnCount);
        
        _tableGrid.selectedRowIndexes = [NSIndexSet indexSetWithIndex:rowIndex];
        _tableGrid.selectedColumnIndexes = [NSIndexSet indexSetWithIndex:filteredIndex];
    }
}

- (void)scrollRangeToVisible:(NSRange)range {
    NSUInteger columnCount = _tableGrid.numberOfColumns;
    NSUInteger rowCount = _tableGrid.numberOfRows;
    NSUInteger cellIndex = range.location;
    NSUInteger rowIndex = _row(cellIndex, rowCount, columnCount);
    NSUInteger filteredIndex = _col(cellIndex, rowCount, columnCount);
        
    [_tableGrid scrollToArea:[_tableGrid.contentView frameOfCellAtColumn:filteredIndex row:rowIndex] animate:NO];
}

- (NSView *)contentViewAtIndex:(NSUInteger)index effectiveCharacterRange:(NSRangePointer)outRange {
    // One big fat view
    outRange->location = 0;
    outRange->length = _tableGrid.numberOfColumns * _tableGrid.numberOfRows;
    return _tableGrid.contentView;
}

- (NSArray<NSValue *> *)rectsForCharacterRange:(NSRange)range {
    NSUInteger columnCount = _tableGrid.numberOfColumns;
    NSUInteger rowCount = _tableGrid.numberOfRows;
    NSUInteger cellIndex = range.location;
    NSUInteger rowIndex = _row(cellIndex, rowCount, columnCount);
    NSUInteger filteredIndex = _col(cellIndex, rowCount, columnCount);
        
    return @[ [NSValue valueWithRect:[_tableGrid.contentView frameOfCellAtColumn:filteredIndex row:rowIndex] ] ];
}

- (NSArray<NSValue *> *)visibleCharacterRanges {
    NSUInteger rowCount = _tableGrid.numberOfRows;

    NSRect visibleRect = _tableGrid.contentView.visibleRect;
    NSPoint topLeft = visibleRect.origin;
    NSPoint bottomRight = NSMakePoint(CGRectGetMaxX(visibleRect), CGRectGetMaxY(visibleRect));
    NSInteger minColumn = [_tableGrid.contentView columnAtPoint:topLeft];
    NSInteger maxColumn = [_tableGrid.contentView columnAtPoint:bottomRight];
    if (maxColumn == NSNotFound) {
        maxColumn = _tableGrid.numberOfColumns-1;
    }
    NSInteger minRow = [_tableGrid.contentView rowAtPoint:topLeft];
    NSInteger maxRow = [_tableGrid.contentView rowAtPoint:bottomRight];
    if (maxRow == NSNotFound) {
        maxRow = _tableGrid.numberOfRows-1;
    }
    NSMutableArray<NSValue *> *arrays_of_ranges = [NSMutableArray array];
    for (NSInteger j=minColumn; j<=maxColumn; j++) {
        NSInteger firstIndex = (j*rowCount + minRow);
        NSInteger lastIndex = (j*rowCount + maxRow);
        NSRange range = NSMakeRange(firstIndex, (lastIndex - firstIndex + 1));
        [arrays_of_ranges addObject:[NSValue valueWithRange:range]];
    }
    return arrays_of_ranges;
}

- (void)drawCharactersInRange:(NSRange)range forContentView:(NSView *)view {
    NSUInteger columnCount = _tableGrid.numberOfColumns;
    NSUInteger rowCount = _tableGrid.numberOfRows;
    NSUInteger cellIndex = range.location;
    NSUInteger rowIndex = _row(cellIndex, rowCount, columnCount);
    NSUInteger filteredIndex = _col(cellIndex, rowCount, columnCount);
    NSCell* cell = [_tableGrid _cellForColumn:filteredIndex row:rowIndex];
    NSRect cellFrame = [_tableGrid.contentView frameOfCellAtColumn:filteredIndex row:rowIndex];
    [cell drawInteriorWithFrame:cellFrame inView:view];
}

- (BOOL)shouldReplaceCharactersInRanges:(NSArray<NSValue *> *)ranges withStrings:(NSArray<NSString *> *)strings {
    NSUInteger columnCount = _tableGrid.numberOfColumns;
    NSUInteger rowCount = _tableGrid.numberOfRows;
    for (NSValue *rangeValue in ranges) {
        NSRange range = rangeValue.rangeValue;
        NSUInteger cellIndex = range.location;
        if (range.location == NSNotFound)
            continue;
        while (cellIndex < range.location + range.length) {
            NSUInteger rowIndex = _row(cellIndex, rowCount, columnCount);
            NSUInteger filteredIndex = _col(cellIndex, rowCount, columnCount);
            if (![_tableGrid _canEditCellAtColumn:filteredIndex row:rowIndex])
                return NO;

            cellIndex++;
        }
    }
    return YES;
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)string {
    NSUInteger columnCount = _tableGrid.numberOfColumns;
    NSUInteger rowCount = _tableGrid.numberOfRows;
    
    NSUInteger cellIndex = range.location;
    NSUInteger rowIndex = _row(cellIndex, rowCount, columnCount);
    NSUInteger filteredIndex = _col(cellIndex, rowCount, columnCount);
    
    [_tableGrid _setObjectValue:string forColumn:filteredIndex row:rowIndex];
}

- (BOOL)isEditable {
    return [_tableGrid.dataSource respondsToSelector:@selector(tableGrid:setObjectValue:forColumn:row:)];
}

- (void)didReplaceCharacters {
    // TODO store up replacements in a "Replace All" and blast them to the data source all at once
    [_tableGrid reloadData];
}


@end
