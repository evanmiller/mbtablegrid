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

#import "MBTableGridFooterView.h"
#import "MBTableGrid.h"
#import "MBTableGridContentView.h"

@interface MBTableGrid ()
- (NSCell *)_footerCellForColumn:(NSUInteger)columnIndex;
- (NSCell *)_footerCellForRow:(NSUInteger)rowIndex;
- (void)_willDisplayFooterMenu:(NSMenu *)menu forColumn:(NSUInteger)columnIndex;
- (void)_willDisplayFooterMenu:(NSMenu *)menu forRow:(NSUInteger)rowIndex;
- (NSRange)_rangeOfColumnsIntersectingRect:(NSRect)rect;
- (NSRange)_rangeOfRowsIntersectingRect:(NSRect)rect;
@end

@implementation MBTableGridFooterView

- (instancetype)initWithFrame:(NSRect)frameRect andTableGrid:(MBTableGrid *)tableGrid
{
    if(self = [super initWithFrame:frameRect]) {
		self.tableGrid = tableGrid;
    }
    return self;
}

- (void)drawRect:(NSRect)rect {
	
	// Draw the column footers
    NSRange columnRange = (self.isVertical ?
                           [self.tableGrid _rangeOfRowsIntersectingRect:[self convertRect:rect toView:self.tableGrid]] :
                           [self.tableGrid _rangeOfColumnsIntersectingRect:[self convertRect:rect toView:self.tableGrid]]);

    // Find the columns to draw
    NSUInteger column = columnRange.location;
    while (column != NSNotFound && column < NSMaxRange(columnRange)) {
        NSRect cellFrame = self.isVertical ? [self footerRectOfRow:column] : [self footerRectOfColumn:column];
		
		// Only draw the header if we need to
		if ([self needsToDrawRect:cellFrame]) {
            NSCell *_cell = self.isVertical ? [self.tableGrid _footerCellForRow:column] : [self.tableGrid _footerCellForColumn:column];
            
			[_cell drawWithFrame:cellFrame inView:self];
		}
		
		column++;
	}
	
}

- (BOOL)isFlipped
{
	return YES;
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    NSPoint local_point = [self convertPoint:theEvent.locationInWindow fromView:nil];
    if (self.isVertical) {
        NSInteger column = [self footerRowAtPoint:local_point];
        [self.tableGrid _willDisplayFooterMenu:self.menu forRow:column];
    } else {
        NSInteger column = [self footerColumnAtPoint:local_point];
        [self.tableGrid _willDisplayFooterMenu:self.menu forColumn:column];
    }
    return self.menu;
}

- (void)mouseDown:(NSEvent *)theEvent
{
    NSPoint mouseLocationInContentView = [self convertPoint:theEvent.locationInWindow fromView:nil];
    NSInteger mouseDownColumn = [self footerColumnAtPoint:mouseLocationInContentView];
    
    if (theEvent.clickCount == 1) {
        // Pass the event back to the MBTableGrid (Used to give First Responder status)
        [self.tableGrid mouseDown:theEvent];
        
        editedColumn = (self.isVertical ?
                        [self footerRowAtPoint:mouseLocationInContentView] :
                        [self footerColumnAtPoint:mouseLocationInContentView]);
        
        if (self.isVertical) {
            if ([self.tableGrid.delegate respondsToSelector:@selector(tableGrid:footerCellClicked:forRow:withEvent:)]) {
                NSCell *cell = [self.tableGrid _footerCellForRow:mouseDownColumn];
                [self.tableGrid.delegate tableGrid:self.tableGrid footerCellClicked:cell forRow:editedColumn withEvent:theEvent];
            }
        } else {
            if ([self.tableGrid.delegate respondsToSelector:@selector(tableGrid:footerCellClicked:forColumn:withEvent:)]) {
                NSCell *cell = [self.tableGrid _footerCellForColumn:mouseDownColumn];
                [self.tableGrid.delegate tableGrid:self.tableGrid footerCellClicked:cell forColumn:editedColumn withEvent:theEvent];
            }
        }
    }
    
    self.needsDisplay = YES;
}

- (NSRect)adjustScroll:(NSRect)proposedVisibleRect
{
    NSRect modifiedRect = proposedVisibleRect;
    
    if (self.isVertical) {
        modifiedRect.origin.x = 0.0;
    } else {
        modifiedRect.origin.y = 0.0;
    }
    
    return modifiedRect;
}

#pragma mark Layout Support

- (NSRect)footerRectOfColumn:(NSUInteger)columnIndex
{
    NSRect rect = [self.tableGrid.contentView rectOfColumn:columnIndex];
	rect.size.height = NSHeight(self.bounds);
	
	return rect;
}

- (NSRect)footerRectOfRow:(NSUInteger)rowIndex
{
    NSRect rect = [self.tableGrid.contentView rectOfRow:rowIndex];
    rect.size.width = NSWidth(self.bounds);
    
    return rect;
}

- (NSInteger)footerColumnAtPoint:(NSPoint)aPoint
{
    return [self.tableGrid.contentView columnAtPoint:aPoint];
}

- (NSInteger)footerRowAtPoint:(NSPoint)aPoint
{
    return [self.tableGrid.contentView rowAtPoint:aPoint];
}

@end
