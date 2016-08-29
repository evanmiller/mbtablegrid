/*
 Copyright (c) 2008 Matthew Ball - http://www.mattballdesign.com
 
 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
 */

#import "MBTableGridContentView.h"

#import "MBTableGrid.h"
#import "MBTableGridCell.h"
#import "MBTableGridEditable.h"

#define kGRAB_HANDLE_HALF_SIDE_LENGTH 3.0f
#define kGRAB_HANDLE_SIDE_LENGTH 6.0f

NSString * const MBTableGridTrackingPartKey = @"part";

@interface MBTableGrid (Private)
- (NSCell *)_cellForColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (id)_objectValueForColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (void)_setObjectValue:(id)value forColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (BOOL)_canEditCellAtColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (void)_setStickyColumn:(MBTableGridEdge)stickyColumn row:(MBTableGridEdge)stickyRow;
- (float)_widthForColumn:(NSUInteger)columnIndex;
- (MBTableGridEdge)_stickyColumn;
- (MBTableGridEdge)_stickyRow;
- (void)_userDidEnterInvalidStringInColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex errorDescription:(NSString *)errorDescription;
- (NSCell *)_footerCellForColumn:(NSUInteger)columnIndex;
- (id)_footerValueForColumn:(NSUInteger)columnIndex;
- (void)_setFooterValue:(id)value forColumn:(NSUInteger)columnIndex;
@end

@interface MBTableGridContentView (Cursors)
- (NSCursor *)_cellSelectionCursor;
- (NSImage *)_cellSelectionCursorImage;
- (NSCursor *)_cellExtendSelectionCursor;
- (NSImage *)_cellExtendSelectionCursorImage;
- (NSImage *)_grabHandleImage;
@end

@interface MBTableGridContentView (DragAndDrop)
- (void)_setDraggingColumnOrRow:(BOOL)flag;
- (void)_setDropColumn:(NSInteger)columnIndex;
- (void)_setDropRow:(NSInteger)rowIndex;
- (void)_timerAutoscrollCallback:(NSTimer *)aTimer;
@end

@implementation MBTableGridContentView

@synthesize showsGrabHandle;
@synthesize rowHeight = _rowHeight;

#pragma mark -
#pragma mark Initialization & Superclass Overrides

- (instancetype)initWithFrame:(NSRect)frameRect andTableGrid:(MBTableGrid*)tableGrid
{
	if(self = [super initWithFrame:frameRect]) {
		
		_tableGrid = tableGrid;
		
		showsGrabHandle = NO;
		mouseDownColumn = NSNotFound;
		mouseDownRow = NSNotFound;
		
		editedColumn = NSNotFound;
		editedRow = NSNotFound;
		
		dropColumn = NSNotFound;
		dropRow = NSNotFound;
        
		grabHandleImage = [self _grabHandleImage];
        grabHandleRect = NSZeroRect;
		
		// Cache the cursor image
		cursorImage = [self _cellSelectionCursorImage];
        cursorExtendSelectionImage = [self _cellExtendSelectionCursorImage];
		
        isCompleting = NO;
		isDraggingColumnOrRow = NO;
        shouldDrawFillPart = MBTableGridTrackingPartNone;

		_rowHeight = 20.0f;
		
		self.wantsLayer = true;
		self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
		[self.layer setDrawsAsynchronously:YES];
		_defaultCell = [[MBTableGridCell alloc] initTextCell:@""];
        [_defaultCell setBordered:YES];
		[_defaultCell setScrollable:YES];
		[_defaultCell setLineBreakMode:NSLineBreakByTruncatingTail];
	}
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)drawRect:(NSRect)rect
{
    
    NSIndexSet *selectedColumns = [_tableGrid selectedColumnIndexes];
    NSIndexSet *selectedRows = [_tableGrid selectedRowIndexes];
	NSUInteger numberOfColumns = _tableGrid.numberOfColumns;
	NSUInteger numberOfRows = _tableGrid.numberOfRows;
	
	NSUInteger firstColumn = NSNotFound;
    NSUInteger lastColumn = (numberOfColumns==0) ? 0 : numberOfColumns - 1;
	NSUInteger firstRow = MAX(0, floor(rect.origin.y / self.rowHeight));
    NSUInteger lastRow = (numberOfRows==0) ? 0 : MIN(numberOfRows - 1, ceil((rect.origin.y + rect.size.height)/self.rowHeight));
	
	// Find the columns to draw
	NSUInteger column = 0;
	while (column < numberOfColumns) {
		NSRect columnRect = [self rectOfColumn:column];
		if (firstColumn == NSNotFound && NSMinX(rect) >= NSMinX(columnRect) && NSMinX(rect) <= NSMaxX(columnRect)) {
			firstColumn = column;
		} else if (firstColumn != NSNotFound && NSMaxX(rect) >= NSMinX(columnRect) && NSMaxX(rect) <= NSMaxX(columnRect)) {
			lastColumn = column;
			break;
		}
		column++;
	}
	
	column = firstColumn;
	while (column <= lastColumn) {
		NSUInteger row = firstRow;
		while (row <= lastRow) {
			NSRect cellFrame = [self frameOfCellAtColumn:column row:row];
			// Only draw the cell if we need to
			NSCell* cell = [_tableGrid _cellForColumn:column row: row];
			
			// If we need to draw then check if we're a popup button. This may be a bit of
			// a hack, but it seems to clear up the problem with the popup button clearing
			// if you don't select a value. It's the editedRow and editedColumn bits that
			// cause the problem. However, if you remove the row and column condition, then
			// if you type into a text field, the text doesn't get cleared first before you
			// start typing. So this seems to make both conditions work.
			
			if ([self needsToDrawRect:cellFrame] && (!(row == editedRow && column == editedColumn))) {
				[cell drawWithFrame:cellFrame inView:self];
			}
			row++;
		}
		column++;
	}
	
	// Draw the selection rectangle
	if(selectedColumns.count && selectedRows.count && _tableGrid.numberOfColumns > 0 && _tableGrid.numberOfRows > 0) {
		NSRect selectionTopLeft = [self frameOfCellAtColumn:selectedColumns.firstIndex row:selectedRows.firstIndex];
		NSRect selectionBottomRight = [self frameOfCellAtColumn:selectedColumns.lastIndex row:selectedRows.lastIndex];
		
		NSRect selectionRect;
		selectionRect.origin = selectionTopLeft.origin;
		selectionRect.size.width = NSMaxX(selectionBottomRight)-selectionTopLeft.origin.x;
		selectionRect.size.height = NSMaxY(selectionBottomRight)-selectionTopLeft.origin.y;
		
        NSRect selectionInsetRect = NSInsetRect(selectionRect, 0, 0);
		NSBezierPath *selectionPath = [NSBezierPath bezierPathWithRect:selectionInsetRect];
		NSAffineTransform *translate = [NSAffineTransform transform];
		//[translate translateXBy:-0.5 yBy:-0.5];
		[selectionPath transformUsingAffineTransform:translate];
		
		NSColor *selectionColor = [NSColor alternateSelectedControlColor];
		
		// If the view is not the first responder, then use a gray selection color
		NSResponder *firstResponder = [self.window firstResponder];
		BOOL disabled = (![firstResponder.class isSubclassOfClass:NSView.class] || ![(NSView *)firstResponder isDescendantOf:_tableGrid] || !self.window.isKeyWindow);
		
		if (disabled) {
			selectionColor = [[selectionColor colorUsingColorSpaceName:NSDeviceWhiteColorSpace] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
        } else if (isFilling) {
            selectionColor = [NSColor colorWithCalibratedRed:0.996 green:0.827 blue:0.176 alpha:1.000];
        }
		
		[[selectionColor colorWithAlphaComponent:0.3] set];
		[selectionPath setLineWidth: 1.0];
		[selectionPath stroke];
        
        [[selectionColor colorWithAlphaComponent:0.2f] set];
        [selectionPath fill];
        
		if (!showsGrabHandle || disabled || [selectedColumns count] > 1) {
			grabHandleRect = NSZeroRect;
		}
        else if (shouldDrawFillPart != MBTableGridTrackingPartNone) {
            // Draw grab handle
            grabHandleRect = NSMakeRect(NSMidX(selectionInsetRect) - kGRAB_HANDLE_HALF_SIDE_LENGTH - 2, (shouldDrawFillPart == MBTableGridTrackingPartFillTop ? NSMinY(selectionInsetRect) : NSMaxY(selectionInsetRect)) - kGRAB_HANDLE_HALF_SIDE_LENGTH - 2, kGRAB_HANDLE_SIDE_LENGTH + 4, kGRAB_HANDLE_SIDE_LENGTH + 4);
            [grabHandleImage drawInRect:grabHandleRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
        }
		
        // Inavlidate cursors so we use the correct cursor for the selection in the right place
        [[self window] invalidateCursorRectsForView:self];
	}
	
	// Draw the column drop indicator
	if (isDraggingColumnOrRow && dropColumn != NSNotFound && dropColumn <= _tableGrid.numberOfColumns && dropRow == NSNotFound) {
		NSRect columnBorder;
		if(dropColumn < _tableGrid.numberOfColumns) {
			columnBorder = [self rectOfColumn:dropColumn];
		}
		else if(dropColumn == _tableGrid.numberOfColumns && dropColumn>0) {
			columnBorder = [self rectOfColumn:dropColumn-1];
		}
		else {
			columnBorder = [self rectOfColumn:0];
			columnBorder.origin.x += columnBorder.size.width;
		}
		columnBorder.origin.x = NSMinX(columnBorder)-2.0;
		columnBorder.size.width = 4.0;
		
		NSColor *selectionColor = [NSColor alternateSelectedControlColor];
		
		NSBezierPath *borderPath = [NSBezierPath bezierPathWithRect:columnBorder];
		[borderPath setLineWidth:2.0];
		
		[selectionColor set];
		[borderPath stroke];
	}
	
	// Draw the row drop indicator
	if (isDraggingColumnOrRow && dropRow != NSNotFound && dropRow <= _tableGrid.numberOfRows && dropColumn == NSNotFound) {
		NSRect rowBorder;
		if(dropRow < _tableGrid.numberOfRows) {
			rowBorder = [self rectOfRow:dropRow];
		} else {
			rowBorder = [self rectOfRow:dropRow-1];
			rowBorder.origin.y += rowBorder.size.height;
		}
		rowBorder.origin.y = NSMinY(rowBorder)-2.0;
		rowBorder.size.height = 4.0;
		
		NSColor *selectionColor = [NSColor alternateSelectedControlColor];
		
		NSBezierPath *borderPath = [NSBezierPath bezierPathWithRect:rowBorder];
		[borderPath setLineWidth:2.0];
		
		[selectionColor set];
		[borderPath stroke];
	}
	
	// Draw the cell drop indicator
	if (!isDraggingColumnOrRow && dropRow != NSNotFound && dropRow <= _tableGrid.numberOfRows && dropColumn != NSNotFound && dropColumn <= _tableGrid.numberOfColumns) {
		NSRect cellFrame = [self frameOfCellAtColumn:dropColumn row:dropRow];
		cellFrame.origin.x -= 2.0;
		cellFrame.origin.y -= 2.0;
		cellFrame.size.width += 3.0;
		cellFrame.size.height += 3.0;
		
		NSBezierPath *borderPath = [NSBezierPath bezierPathWithRect:NSInsetRect(cellFrame, 2, 2)];
		
		NSColor *dropColor = [NSColor alternateSelectedControlColor];
		[dropColor set];
		
		borderPath.lineWidth = 2.0;
		[borderPath stroke];
	}
}

- (void)updateCell:(id)sender {
	// This is here just to satisfy NSLevelIndicatorCell because
	// when this view is the controlView for the NSLevelIndicatorCell,
	// it calls updateCell on this controlView.
}

- (void)updateLevelIndicator:(NSNumber *)value {
	NSInteger selectedColumn = [self.tableGrid.selectedColumnIndexes firstIndex];
	NSInteger selectedRow = [self.tableGrid.selectedRowIndexes firstIndex];
	// sanity check to make sure we have an NSNumber.
	// I've observed that when the user lets go of the mouse,
	// the value parameter becomes the MBTableGridContentView
	// object for some reason.
	if ([value isKindOfClass:[NSNumber class]]) {
		[self.tableGrid _setObjectValue:value forColumn:selectedColumn row:selectedRow];
		NSRect cellFrame = [self.tableGrid frameOfCellAtColumn:selectedColumn row:selectedRow];
		[self.tableGrid setNeedsDisplayInRect:cellFrame];
	}
}

- (BOOL)isFlipped
{
	return YES;
}

- (void)mouseDown:(NSEvent *)theEvent
{
	// Setup the timer for autoscrolling
	// (the simply calling autoscroll: from mouseDragged: only works as long as the mouse is moving)
	autoscrollTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(_timerAutoscrollCallback:) userInfo:nil repeats:YES];
	
	NSPoint mouseLocationInContentView = [self convertPoint:theEvent.locationInWindow fromView:nil];
	mouseDownColumn = [self columnAtPoint:mouseLocationInContentView];
	mouseDownRow = [self rowAtPoint:mouseLocationInContentView];

	if(mouseDownRow == NSNotFound) {
		return;
	}
    
    // If the column wasn't found, probably need to flush the cached column rects
    if (mouseDownColumn == NSNotFound) {
        [self.tableGrid.columnRects removeAllObjects];
        
        mouseDownColumn = [self columnAtPoint:mouseLocationInContentView];
    }
    
	NSCell *cell = [self.tableGrid _cellForColumn:mouseDownColumn row: mouseDownRow];
	BOOL cellEditsOnFirstClick = [cell respondsToSelector:@selector(editOnFirstClick)] ? ([(id<MBTableGridEditable>)cell editOnFirstClick]==YES) : self.tableGrid.singleClickCellEdit;
    isFilling = NO;
    
	if (theEvent.clickCount == 1) {
		// Pass the event back to the MBTableGrid (Used to give First Responder status)
		[self.tableGrid mouseDown:theEvent];
		
		NSUInteger selectedColumn = [self.tableGrid.selectedColumnIndexes firstIndex];
		NSUInteger selectedRow = [self.tableGrid.selectedRowIndexes firstIndex];

        isFilling = showsGrabHandle && NSPointInRect(mouseLocationInContentView, grabHandleRect);
        
        if (isFilling) {
            numberOfRowsWhenStartingFilling = self.tableGrid.numberOfRows;
            
            if (mouseDownRow == selectedRow - 1 || mouseDownRow == selectedRow + 1) {
                mouseDownRow = selectedRow;
            }
        }
        
		// Edit an already selected cell if it doesn't edit on first click
		if (selectedColumn == mouseDownColumn && selectedRow == mouseDownRow && !cellEditsOnFirstClick && !isFilling) {
			[self editSelectedCell:self text:nil];

		// Expand a selection when the user holds the shift key
		} else if (([theEvent modifierFlags] & NSShiftKeyMask) && self.tableGrid.allowsMultipleSelection && !isFilling) {
			// If the shift key was held down, extend the selection
			NSUInteger stickyColumn = [self.tableGrid.selectedColumnIndexes firstIndex];
			NSUInteger stickyRow = [self.tableGrid.selectedRowIndexes firstIndex];
			
			MBTableGridEdge stickyColumnEdge = [self.tableGrid _stickyColumn];
			MBTableGridEdge stickyRowEdge = [self.tableGrid _stickyRow];
			
			// Compensate for sticky edges
			if (stickyColumnEdge == MBTableGridRightEdge) {
				stickyColumn = [self.tableGrid.selectedColumnIndexes lastIndex];
			}
			if (stickyRowEdge == MBTableGridBottomEdge) {
				stickyRow = [self.tableGrid.selectedRowIndexes lastIndex];
			}
			
			NSRange selectionColumnRange = NSMakeRange(stickyColumn, mouseDownColumn-stickyColumn+1);
			NSRange selectionRowRange = NSMakeRange(stickyRow, mouseDownRow-stickyRow+1);
			
			if (mouseDownColumn < stickyColumn) {
				selectionColumnRange = NSMakeRange(mouseDownColumn, stickyColumn-mouseDownColumn+1);
				stickyColumnEdge = MBTableGridRightEdge;
			} else {
				stickyColumnEdge = MBTableGridLeftEdge;
			}
			
			if (mouseDownRow < stickyRow) {
				selectionRowRange = NSMakeRange(mouseDownRow, stickyRow-mouseDownRow+1);
				stickyRowEdge = MBTableGridBottomEdge;
			} else {
				stickyRowEdge = MBTableGridTopEdge;
			}
			
			// Select the proper cells
			self.tableGrid.selectedColumnIndexes = [NSIndexSet indexSetWithIndexesInRange:selectionColumnRange];
			self.tableGrid.selectedRowIndexes = [NSIndexSet indexSetWithIndexesInRange:selectionRowRange];
			
			// Set the sticky edges
			[self.tableGrid _setStickyColumn:stickyColumnEdge row:stickyRowEdge];
		// First click on a cell without shift key modifier
		} else {
			// No modifier keys, so change the selection
			// Only notify observers once even though we change the selection twice
			[self.tableGrid setSelectedColumnIndexes:[NSIndexSet indexSetWithIndex:mouseDownColumn] notify: NO];
			self.tableGrid.selectedRowIndexes = [NSIndexSet indexSetWithIndex:mouseDownRow];
			[self.tableGrid _setStickyColumn:MBTableGridLeftEdge row:MBTableGridTopEdge];
		}
    // Edit cells on double click if they don't already edit on first click
	}

	// Any cells that should edit on first click are handled here
	if (cellEditsOnFirstClick) {
		[self editSelectedCell:self text:nil];
	}

	[self setNeedsDisplay:YES];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	if (mouseDownColumn != NSNotFound && mouseDownRow != NSNotFound && self.tableGrid.allowsMultipleSelection) {
		NSPoint loc = [self convertPoint:theEvent.locationInWindow fromView:nil];
		NSInteger column = [self columnAtPoint:loc];
		NSInteger row = [self rowAtPoint:loc];
        NSInteger numberOfRows = self.tableGrid.numberOfRows;
        
        // While filling, if dragging beyond the size of the table, add more rows
        if (isFilling && loc.y > 0.0 && row == NSNotFound && [self.tableGrid.dataSource respondsToSelector:@selector(tableGrid:addRows:)]) {
            NSRect rowRect = [self rectOfRow:numberOfRows];
            NSInteger numberOfRowsToAdd = ((loc.y - rowRect.origin.y) / rowRect.size.height) + 1;
            
            if (numberOfRowsToAdd > 0 && [self.tableGrid.dataSource tableGrid:self.tableGrid addRows:numberOfRowsToAdd]) {
                row = [self rowAtPoint:loc];
            }
            
            [self resetCursorRects];
        }
        
        // While filling, if dragging upwards, remove any rows added during the fill operation
        if (isFilling && row < numberOfRows && [self.tableGrid.dataSource respondsToSelector:@selector(tableGrid:removeRows:)]) {
            NSInteger firstRowToRemove = row + 1;
            
            if (firstRowToRemove < numberOfRowsWhenStartingFilling) {
                firstRowToRemove = numberOfRowsWhenStartingFilling;
            }
            
            NSIndexSet *rowIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstRowToRemove, numberOfRows - firstRowToRemove)];
            
            [self.tableGrid.dataSource tableGrid:self.tableGrid removeRows:rowIndexes];
            
            [self resetCursorRects];
        }
		
		MBTableGridEdge columnEdge = MBTableGridLeftEdge;
		MBTableGridEdge rowEdge = MBTableGridTopEdge;
		
		// Select the appropriate number of columns
		if(column != NSNotFound && !isFilling) {
			NSInteger firstColumnToSelect = mouseDownColumn;
			NSInteger numberOfColumnsToSelect = column-mouseDownColumn+1;
			if(column < mouseDownColumn) {
				firstColumnToSelect = column;
				numberOfColumnsToSelect = mouseDownColumn-column+1;
				
				// Set the sticky edge to the right
				columnEdge = MBTableGridRightEdge;
			}
			
			self.tableGrid.selectedColumnIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstColumnToSelect,numberOfColumnsToSelect)];
			
		}
		
		// Select the appropriate number of rows
		if(row != NSNotFound) {
			NSInteger firstRowToSelect = mouseDownRow;
			NSInteger numberOfRowsToSelect = row-mouseDownRow+1;
			if(row < mouseDownRow) {
				firstRowToSelect = row;
				numberOfRowsToSelect = mouseDownRow-row+1;
				
				// Set the sticky row to the bottom
				rowEdge = MBTableGridBottomEdge;
			}
			
			self.tableGrid.selectedRowIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstRowToSelect,numberOfRowsToSelect)];
			
		}
		
		// Set the sticky edges
		[self.tableGrid _setStickyColumn:columnEdge row:rowEdge];
		
        [self setNeedsDisplay:YES];
	}
}

- (void)mouseUp:(NSEvent *)theEvent
{
	[autoscrollTimer invalidate];
	autoscrollTimer = nil;
	
	if (isFilling) {
		id value = [self.tableGrid _objectValueForColumn:mouseDownColumn row:mouseDownRow];
		
		[self.tableGrid.selectedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
			[self.tableGrid _setObjectValue:[value copy] forColumn:mouseDownColumn row:idx];
		}];
		
        NSInteger numberOfRows = self.tableGrid.numberOfRows;
        
        // If rows were added, tell the delegate
        if (isFilling && numberOfRows > numberOfRowsWhenStartingFilling && [self.tableGrid.delegate respondsToSelector:@selector(tableGrid:didAddRows:)]) {
            NSIndexSet *rowIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(numberOfRowsWhenStartingFilling, numberOfRows - numberOfRowsWhenStartingFilling)];
            
            [self.tableGrid.delegate tableGrid:self.tableGrid didAddRows:rowIndexes];
        }
        
		isFilling = NO;
        
        [self.tableGrid setNeedsDisplay:YES];
	}
	
	mouseDownColumn = NSNotFound;
	mouseDownRow = NSNotFound;
}

- (void)mouseEntered:(NSEvent *)theEvent
{
    NSDictionary *dict = theEvent.userData;
    MBTableGridTrackingPart part = [dict[MBTableGridTrackingPartKey] integerValue];
    
    if (shouldDrawFillPart != part) {
        shouldDrawFillPart = part;
        self.needsDisplay = YES;
    }
}

- (void)mouseExited:(NSEvent *)theEvent
{
    if (shouldDrawFillPart != MBTableGridTrackingPartNone) {
        shouldDrawFillPart = MBTableGridTrackingPartNone;
		self.needsDisplay = YES;
    }
}

#pragma mark Cursor Rects

- (void)resetCursorRects
{
	NSIndexSet *selectedColumns = self.tableGrid.selectedColumnIndexes;
	NSIndexSet *selectedRows = self.tableGrid.selectedRowIndexes;

	if (selectedColumns.count > 0 && selectedRows.count > 0) {
		NSRect selectionTopLeft = [self frameOfCellAtColumn:[selectedColumns firstIndex] row:[selectedRows firstIndex]];
		NSRect selectionBottomRight = [self frameOfCellAtColumn:[selectedColumns lastIndex] row:[selectedRows lastIndex]];
		
		NSRect selectionRect;
		selectionRect.origin = selectionTopLeft.origin;
		selectionRect.size.width = NSMaxX(selectionBottomRight)-selectionTopLeft.origin.x;
		selectionRect.size.height = NSMaxY(selectionBottomRight)-selectionTopLeft.origin.y;

		[self addCursorRect:selectionRect cursor:[NSCursor arrowCursor]];

		[self addCursorRect:[self visibleRect] cursor:[self _cellSelectionCursor]];
		
		if(showsGrabHandle) {
			[self addCursorRect:grabHandleRect cursor:[self _cellExtendSelectionCursor]];
		}
		
		// Update tracking areas here, to leverage the selection variables
		for (NSTrackingArea *trackingArea in self.trackingAreas) {
			[self removeTrackingArea:trackingArea];
		}
		
		if (selectedColumns.count == 1) {
			NSRect fillTrackingRect = [self rectOfColumn:[selectedColumns firstIndex]];
			fillTrackingRect.size.height = self.frame.size.height;
			NSRect topFillTrackingRect, bottomFillTrackingRect;
			
			NSDivideRect(fillTrackingRect, &topFillTrackingRect, &bottomFillTrackingRect, selectionRect.origin.y + (selectionRect.size.height / 2.0), NSRectEdgeMinY);
			
			[self addTrackingArea:[[NSTrackingArea alloc] initWithRect:topFillTrackingRect options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow owner:self userInfo:@{MBTableGridTrackingPartKey : @(MBTableGridTrackingPartFillTop)}]];
			[self addTrackingArea:[[NSTrackingArea alloc] initWithRect:bottomFillTrackingRect options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow owner:self userInfo:@{MBTableGridTrackingPartKey : @(MBTableGridTrackingPartFillBottom)}]];
		}
	}
}

#pragma mark -
#pragma mark Notifications

#pragma mark Field Editor

- (void)textDidBeginEditingWithEditor:(NSText *)editor
{
    isAutoEditing = YES;
}

- (void)textDidBeginEditing:(NSNotification *)notification
{
    isAutoEditing = NO;
}

- (void)textDidChange:(NSNotification *)notification
{
    isAutoEditing = NO;
}

- (void)textDidEndEditing:(NSNotification *)aNotification
{
    isAutoEditing = NO;
	NSInteger movementType = [aNotification.userInfo[@"NSTextMovement"] integerValue];

	// Give focus back to the table grid (the field editor took it)
	[[self window] makeFirstResponder:self.tableGrid];

	if(movementType != NSCancelTextMovement) {
		NSString *stringValue = [[[aNotification object] string] copy];
		[self.tableGrid _setObjectValue:stringValue forColumn:editedColumn row:editedRow];
	}

	editedColumn = NSNotFound;
	editedRow = NSNotFound;
	
	// End the editing session
	NSText* fe = [[self window] fieldEditor:NO forObject:self];
	[[self.tableGrid cell] endEditing:fe];


	switch (movementType) {
		case NSBacktabTextMovement:
			[self.tableGrid moveLeft:self];
			break;

		case NSTabTextMovement:
			[self.tableGrid moveRight:self];
			break;

		case NSReturnTextMovement:
			if([NSApp currentEvent].modifierFlags & NSShiftKeyMask) {
				[self.tableGrid moveUp:self];
			}
			else {
				[self.tableGrid moveDown:self];
			}
			break;

		case NSUpTextMovement:
			[self.tableGrid moveUp:self];
			break;

		default:
			break;
	}
}

#pragma mark -
#pragma mark Protocol Methods

#pragma mark NSDraggingDestination

/*
 * These methods simply pass the drag event back to the table grid.
 * They are only required for autoscrolling.
 */

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	// Setup the timer for autoscrolling 
	// (the simply calling autoscroll: from mouseDragged: only works as long as the mouse is moving)
	autoscrollTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(_timerAutoscrollCallback:) userInfo:nil repeats:YES];
	
	return [self.tableGrid draggingEntered:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
	return [self.tableGrid draggingUpdated:sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	[autoscrollTimer invalidate];
	autoscrollTimer = nil;
	
	[self.tableGrid draggingExited:sender];
}

- (void)draggingEnded:(id <NSDraggingInfo>)sender
{
	[self.tableGrid draggingEnded:sender];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	return [self.tableGrid prepareForDragOperation:sender];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	return [self.tableGrid performDragOperation:sender];
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	[self.tableGrid concludeDragOperation:sender];
}

#pragma mark -
#pragma mark Subclass Methods

/*
- (MBTableGrid *)tableGrid
{
	return (MBTableGrid *)[[self enclosingScrollView] superview];
}
*/

- (void)editSelectedCell:(id)sender text:(NSString *)aString
{
	NSInteger selectedColumn = [self.tableGrid.selectedColumnIndexes firstIndex];
	NSInteger selectedRow = [self.tableGrid.selectedRowIndexes firstIndex];
	NSCell *selectedCell = [self.tableGrid _cellForColumn:selectedColumn row: selectedRow];

	// Check if the cell can be edited
	if(![self.tableGrid _canEditCellAtColumn:selectedColumn row:selectedColumn]) {
		editedColumn = NSNotFound;
		editedRow = NSNotFound;
		return;
	}

	// Select it and only it
	if([self.tableGrid.selectedColumnIndexes count] > 1 && editedColumn != NSNotFound) {
		self.tableGrid.selectedColumnIndexes = [NSIndexSet indexSetWithIndex:editedColumn];
	}
	if([self.tableGrid.selectedRowIndexes count] > 1 && editedRow != NSNotFound) {
		self.tableGrid.selectedRowIndexes = [NSIndexSet indexSetWithIndex:editedRow];
	}

	// Get the top-left selection
	editedColumn = selectedColumn;
	editedRow = selectedRow;

	NSRect cellFrame = [self frameOfCellAtColumn:editedColumn row:editedRow];

	[selectedCell setEditable:YES];
	[selectedCell setSelectable:YES];
	
	id currentValue = [self.tableGrid _objectValueForColumn:editedColumn row:editedRow];

	NSText *editor = [self.window fieldEditor:YES forObject:self];
	editor.delegate = self;
	editor.alignment = selectedCell.alignment;
	editor.font = selectedCell.font;
	selectedCell.stringValue = currentValue;
	editor.string = currentValue;
	NSEvent* event = [NSApp currentEvent];
	if(event != nil && event.type == NSLeftMouseDown) {
		[selectedCell editWithFrame:cellFrame inView:self editor:editor delegate:self event:[NSApp currentEvent]];
	}
	else {
		[selectedCell selectWithFrame:cellFrame inView:self editor:editor delegate:self start:0 length:[currentValue length]];
	}
}

#pragma mark Layout Support

- (NSRect)rectOfColumn:(NSUInteger)columnIndex
{
	NSRect rect = NSZeroRect;
	BOOL foundRect = NO;
	if (columnIndex < self.tableGrid.numberOfColumns) {
		NSValue *cachedRectValue = self.tableGrid.columnRects[@(columnIndex)];
		if (cachedRectValue) {
			rect = [cachedRectValue rectValue];
			foundRect = YES;
		}
	
		if (!foundRect) {
			float width = [self.tableGrid _widthForColumn:columnIndex];
			
			rect = NSMakeRect(0, 0, width, [self frame].size.height);
			//rect.origin.x += 60.0 * columnIndex;
			
			NSUInteger i = 0;
			while(i < columnIndex) {
				float headerWidth = [self.tableGrid _widthForColumn:i];
				rect.origin.x += headerWidth;
				i++;
			}
		
			self.tableGrid.columnRects[@(columnIndex)] = [NSValue valueWithRect:rect];

		}
	}
	
	return rect;
}

- (NSRect)rectOfRow:(NSUInteger)rowIndex
{
	NSRect rect = NSMakeRect(0, 0, [self frame].size.width, self.rowHeight);
	rect.origin.y += self.rowHeight * rowIndex;
	return rect;
}

- (NSRect)frameOfCellAtColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex
{
	NSRect columnRect = [self rectOfColumn:columnIndex];
	NSRect rowRect = [self rectOfRow:rowIndex];
	return NSMakeRect(columnRect.origin.x, rowRect.origin.y, columnRect.size.width, rowRect.size.height);
}

- (NSInteger)columnAtPoint:(NSPoint)aPoint
{
	NSInteger column = 0;
	while(column < self.tableGrid.numberOfColumns) {
		NSRect columnFrame = [self rectOfColumn:column];
		if(aPoint.x > columnFrame.origin.x && aPoint.x < (columnFrame.origin.x + columnFrame.size.width)) {
			return column;
		}
		column++;
	}
	return NSNotFound;
}

- (NSInteger)rowAtPoint:(NSPoint)aPoint
{
	NSInteger row = aPoint.y / self.rowHeight;
	if(row >= 0 && row < self.tableGrid.numberOfRows) {
		return row;
	}
	return NSNotFound;
}

@end

@implementation MBTableGridContentView (Cursors)

- (NSCursor *)_cellSelectionCursor
{
	NSCursor *cursor = [[NSCursor alloc] initWithImage:cursorImage hotSpot:NSMakePoint(8, 8)];
	return cursor;
}

/**
 * @warning		This method is not as efficient as it could be, but
 *				it should only be called once, at initialization.
 *				TODO: Make it faster
 */
- (NSImage *)_cellSelectionCursorImage
{
	NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(20, 20)];
	[image lockFocusFlipped:YES];
	
	NSRect horizontalInner = NSMakeRect(7.0, 2.0, 2.0, 12.0);
	NSRect verticalInner = NSMakeRect(2.0, 7.0, 12.0, 2.0);
	
	NSRect horizontalOuter = NSInsetRect(horizontalInner, -1.0, -1.0);
	NSRect verticalOuter = NSInsetRect(verticalInner, -1.0, -1.0);
	
	// Set the shadow
	NSShadow *shadow = [[NSShadow alloc] init];
	[shadow setShadowColor:[NSColor colorWithDeviceWhite:0.0 alpha:0.8]];
	[shadow setShadowBlurRadius:2.0];
	[shadow setShadowOffset:NSMakeSize(0, -1.0)];
	
	[[NSGraphicsContext currentContext] saveGraphicsState];
	
	[shadow set];
	
	[[NSColor blackColor] set];
	NSRectFill(horizontalOuter);
	NSRectFill(verticalOuter);
	
	[[NSGraphicsContext currentContext] restoreGraphicsState];
	
	// Fill them again to compensate for the shadows
	NSRectFill(horizontalOuter);
	NSRectFill(verticalOuter);
	
	[[NSColor whiteColor] set];
	NSRectFill(horizontalInner);
	NSRectFill(verticalInner);
	
	[image unlockFocus];
	
	return image;
}

- (NSCursor *)_cellExtendSelectionCursor
{
	NSCursor *cursor = [[NSCursor alloc] initWithImage:cursorExtendSelectionImage hotSpot:NSMakePoint(8, 8)];
	return cursor;
}

/**
 * @warning		This method is not as efficient as it could be, but
 *				it should only be called once, at initialization.
 *				TODO: Make it faster
 */
- (NSImage *)_cellExtendSelectionCursorImage
{
	NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(20, 20)];
	[image lockFocusFlipped:YES];
	
	NSRect horizontalInner = NSMakeRect(7.0, 1.0, 0.5, 12.0);
	NSRect verticalInner = NSMakeRect(1.0, 6.0, 12.0, 0.5);
	
	NSRect horizontalOuter = NSInsetRect(horizontalInner, -1.0, -1.0);
	NSRect verticalOuter = NSInsetRect(verticalInner, -1.0, -1.0);
	
	[[NSGraphicsContext currentContext] saveGraphicsState];

	[[NSColor whiteColor] set];
	NSRectFill(horizontalOuter);
	NSRectFill(verticalOuter);
	
	[[NSGraphicsContext currentContext] restoreGraphicsState];
	
	// Fill them again to compensate for the shadows
	NSRectFill(horizontalOuter);
	NSRectFill(verticalOuter);
	
	[[NSColor blackColor] set];
	NSRectFill(horizontalInner);
	NSRectFill(verticalInner);
	
	[image unlockFocus];
	
	return image;
}

- (NSImage *)_grabHandleImage;
{
	NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(kGRAB_HANDLE_SIDE_LENGTH, kGRAB_HANDLE_SIDE_LENGTH)];
	[image lockFocusFlipped:YES];
	
	NSGraphicsContext *gc = [NSGraphicsContext currentContext];
	
	// Save the current graphics context
	[gc saveGraphicsState];
	
	// Set the color in the current graphics context
	
	[[NSColor darkGrayColor] setStroke];
	[[NSColor colorWithCalibratedRed:0.996 green:0.827 blue:0.176 alpha:1.000] setFill];
	
	// Create our circle path
	NSRect rect = NSMakeRect(1.0, 1.0, kGRAB_HANDLE_SIDE_LENGTH - 2.0, kGRAB_HANDLE_SIDE_LENGTH - 2.0);
	NSBezierPath *circlePath = [NSBezierPath bezierPath];
	[circlePath setLineWidth:0.5];
	[circlePath appendBezierPathWithOvalInRect: rect];
	
	// Outline and fill the path
	[circlePath fill];
	[circlePath stroke];
	
	// Restore the context
	[gc restoreGraphicsState];
	[image unlockFocus];
	
	return image;
}

@end

@implementation MBTableGridContentView (DragAndDrop)

- (void)_setDraggingColumnOrRow:(BOOL)flag
{
	isDraggingColumnOrRow = flag;
}

- (void)_setDropColumn:(NSInteger)columnIndex
{
	dropColumn = columnIndex;
	[self setNeedsDisplay:YES];
}

- (void)_setDropRow:(NSInteger)rowIndex
{
	dropRow = rowIndex;
	[self setNeedsDisplay:YES];
}

- (void)_timerAutoscrollCallback:(NSTimer *)aTimer
{
	NSEvent* event = [NSApp currentEvent];
    if ([event type] == NSLeftMouseDragged )
        [self autoscroll:event];
}

@end
