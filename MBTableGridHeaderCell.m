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

#import "MBTableGridHeaderCell.h"
#import "MBTableGridHeaderView.h"
#import "MBTableGrid.h"

extern CGFloat MBTableHeaderSortIndicatorWidth;
extern CGFloat MBTableHeaderSortIndicatorMargin;

#define kSortIndicatorXInset        4.0      /* Number of pixels to inset the drawing of the indicator from the right edge */

@interface MBTableGridHeaderCell ()

@end

@interface MBTableGrid (Private)
- (NSColor *)_selectionColor;
@end

#pragma mark -

@implementation MBTableGridHeaderCell

@synthesize orientation;
//@synthesize labelFont;

- (NSColor*)borderColor
{
    if (_borderColor == nil)
        _borderColor = NSColor.quaternaryLabelColor;
	return _borderColor;
}

- (NSColor*)textColor
{
	if (_textColor == nil)
		_textColor = NSColor.headerTextColor;
	return _textColor;
}

- (NSFont*)labelFont
{
	if (_labelFont == nil)
		_labelFont = [NSFont labelFontOfSize:NSFont.labelFontSize];
	return _labelFont;
}

- (NSRect)sortIndicatorRectForBounds:(NSRect)rect {
    NSRect indicatorRect = NSZeroRect;
    NSSize sortImageSize = NSMakeSize(MBTableHeaderSortIndicatorWidth, MBTableHeaderSortIndicatorWidth);
    indicatorRect.size = sortImageSize;
    indicatorRect.origin.x = NSMaxX(rect) - (sortImageSize.width + MBTableHeaderSortIndicatorMargin);
    indicatorRect.origin.y = NSMinY(rect) + roundf((NSHeight(rect) - sortImageSize.height) / 2.0);
    return indicatorRect;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(MBTableGridHeaderView *)controlView
{
	NSRect cellFrameRect = cellFrame;
	
	[NSColor.windowBackgroundColor set];
	NSRectFill(cellFrame);
		
	if(self.orientation == MBTableHeaderHorizontalOrientation) {
		// Draw the right border
		NSRect borderLine = NSMakeRect(NSMaxX(cellFrameRect)-1, NSMinY(cellFrameRect) + 4.0, 1.0, NSHeight(cellFrameRect) - 4.0);
		[self.borderColor set];
		NSRectFill(borderLine);
		
		// Draw the bottom border
		NSRect bottomLine = NSMakeRect(NSMinX(cellFrameRect), NSMaxY(cellFrameRect)-1.0, NSWidth(cellFrameRect), 1.0);
		NSRectFill(bottomLine);
		
	} else if(self.orientation == MBTableHeaderVerticalOrientation) {
		// Draw the right border
		[self.borderColor set];
		NSRect borderLine = NSMakeRect(NSMaxX(cellFrameRect)-1, NSMinY(cellFrameRect), 1.0, NSHeight(cellFrameRect)-1);
		NSRectFill(borderLine);
		
		// Draw the bottom border
		NSRect bottomLine = NSMakeRect(NSMinX(cellFrameRect) + 4.0, NSMaxY(cellFrameRect)-1.0, NSWidth(cellFrameRect) - 4.0, 1.0);
		NSRectFill(bottomLine);
	}
	
    if(self.state == NSControlStateValueOn) {
		NSRect fillRect = cellFrameRect;
		if(self.orientation == MBTableHeaderVerticalOrientation) {
			fillRect.origin.y -= 1.0;
			fillRect.origin.x += 2.0;
			fillRect.size.height += 2.0;
			fillRect.size.width += 4.0;
		}
		else if(self.orientation == MBTableHeaderHorizontalOrientation) {
			fillRect.size.height += 4.0;
			fillRect.origin.x -= 1.0;
			fillRect.size.width += 2.0;
		}
		NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:fillRect xRadius:4.0 yRadius:4.0];

        NSColor *overlayColor = [controlView.tableGrid._selectionColor colorWithAlphaComponent:0.26];
		[overlayColor set];
		[path fill];
	}
	
	// Draw the text
	[self drawInteriorWithFrame:cellFrameRect inView:controlView];
}

- (NSAttributedString *)attributedStringValue {
    NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    if (self.orientation == MBTableHeaderVerticalOrientation) {
        paragraphStyle.alignment = NSTextAlignmentCenter;
    }
	NSDictionary<NSAttributedStringKey, id> *attributes = @{
		NSFontAttributeName: self.labelFont,
		NSForegroundColorAttributeName: self.textColor,
        NSParagraphStyleAttributeName: paragraphStyle
	};
	return [[NSAttributedString alloc] initWithString:self.stringValue attributes:attributes];
}

- (void)drawSortIndicatorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView ascending:(BOOL)ascending priority:(NSInteger)priority {
    if (!self.sortIndicatorColor)
        return;
    
    NSRect indicatorRect = [self sortIndicatorRectForBounds:cellFrame];
    NSBezierPath *path = [NSBezierPath bezierPath];
    path.lineCapStyle = NSRoundLineCapStyle;
    path.lineWidth = 1.5;
    [self.sortIndicatorColor setStroke];
    [path moveToPoint:NSMakePoint(NSMinX(indicatorRect) + path.lineWidth / 2,
                                  indicatorRect.origin.y + 0.25 * indicatorRect.size.height)];
    [path lineToPoint:NSMakePoint(NSMidX(indicatorRect),
                                  indicatorRect.origin.y + 0.75 * indicatorRect.size.height)];
    [path lineToPoint:NSMakePoint(NSMaxX(indicatorRect) - path.lineWidth / 2,
                                  indicatorRect.origin.y + 0.25 * indicatorRect.size.height)];
    if (ascending) {
        NSAffineTransform *transform = [NSAffineTransform transform];
        [transform translateXBy:0.0 yBy:2.5*indicatorRect.size.height];
        [transform scaleXBy:1.0 yBy:-1.0];
        [path transformUsingAffineTransform:transform];
    }
    [path stroke];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSRect cellFrameRect = cellFrame;

	static CGFloat TEXT_PADDING = 6;
	NSRect textFrame;
	CGSize stringSize = self.attributedStringValue.size;
    NSStringDrawingOptions options = (NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin);
	if (self.orientation == MBTableHeaderHorizontalOrientation) {
		textFrame = NSMakeRect(cellFrameRect.origin.x + TEXT_PADDING,
							   cellFrameRect.origin.y + (cellFrameRect.size.height - stringSize.height)/2,
							   cellFrameRect.size.width - TEXT_PADDING,
							   stringSize.height);
	} else {
        NSRect boundingRect = [self.attributedStringValue boundingRectWithSize:cellFrame.size
                                                                       options:options];
        if (boundingRect.size.height < cellFrame.size.height) {
            textFrame = NSMakeRect(cellFrameRect.origin.x,
                                   cellFrameRect.origin.y + (cellFrameRect.size.height - boundingRect.size.height)/2,
                                   cellFrame.size.width,
                                   cellFrame.size.height - (cellFrameRect.size.height - boundingRect.size.height)/2);
        } else {
            textFrame = cellFrame;
        }
	}
	[self.attributedStringValue drawWithRect:textFrame options:options];
    [self drawSortIndicatorWithFrame:cellFrame inView:controlView ascending:self.sortIndicatorAscending priority:0];
}

@end
