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

#define kSortIndicatorXInset		4.0  	/* Number of pixels to inset the drawing of the indicator from the right edge */

@implementation MBTableGridHeaderCell

@synthesize orientation;

- (NSRect)sortIndicatorRectForBounds:(NSRect)theRect {
    NSRect indicatorRect = NSZeroRect;
    NSSize sortImageSize = [self.sortIndicatorImage size];
    indicatorRect.size = sortImageSize;
    indicatorRect.origin.x = NSMaxX(theRect) - (sortImageSize.width + kSortIndicatorXInset);
    indicatorRect.origin.y = NSMinY(theRect) + roundf((NSHeight(theRect) - sortImageSize.height) / 2.0);
    return indicatorRect;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSRect cellFrameRect = cellFrame;
	
	NSColor *topColor = [NSColor colorWithDeviceWhite:0.95 alpha:1.0];
	NSColor *sideColor = [NSColor colorWithDeviceWhite:1.0 alpha:0.4];
	NSColor *borderColor = [NSColor colorWithDeviceWhite:0.8 alpha:1.0];
		
	if(self.orientation == MBTableHeaderHorizontalOrientation) {
		// Draw the side bevels
		NSRect sideLine = NSMakeRect(NSMinX(cellFrameRect), NSMinY(cellFrameRect), 1.0, NSHeight(cellFrameRect));
		[sideColor set];
		[[NSBezierPath bezierPathWithRect:sideLine] fill];
		sideLine.origin.x = NSMaxX(cellFrameRect)-2.0;
		[[NSBezierPath bezierPathWithRect:sideLine] fill];
		        
		// Draw the right border
		NSRect borderLine = NSMakeRect(NSMaxX(cellFrameRect)-1, NSMinY(cellFrameRect), 1.0, NSHeight(cellFrameRect));
		[borderColor set];
		NSRectFill(borderLine);
		
		// Draw the bottom border
		NSRect bottomLine = NSMakeRect(NSMinX(cellFrameRect), NSMaxY(cellFrameRect)-1.0, NSWidth(cellFrameRect), 1.0);
		NSRectFill(bottomLine);
		
	} else if(self.orientation == MBTableHeaderVerticalOrientation) {
		// Draw the top bevel line
		NSRect topLine = NSMakeRect(NSMinX(cellFrameRect), NSMinY(cellFrameRect), NSWidth(cellFrameRect), 1.0);
		[topColor set];
		NSRectFill(topLine);
		
		// Draw the right border
		[borderColor set];
		NSRect borderLine = NSMakeRect(NSMaxX(cellFrameRect)-1, NSMinY(cellFrameRect), 1.0, NSHeight(cellFrameRect));
		NSRectFill(borderLine);
		
		// Draw the bottom border
		NSRect bottomLine = NSMakeRect(NSMinX(cellFrameRect), NSMaxY(cellFrameRect)-1.0, NSWidth(cellFrameRect), 1.0);
		NSRectFill(bottomLine);
	}
	
	if([self state] == NSOnState) {
		NSBezierPath *path = [NSBezierPath bezierPathWithRect:cellFrameRect];
		NSColor *overlayColor = [[NSColor alternateSelectedControlColor] colorWithAlphaComponent:0.2];
		[overlayColor set];
		[path fill];
	}
	
	// Draw the text
	[self drawInteriorWithFrame:cellFrameRect inView:controlView];
}

- (NSAttributedString *)attributedStringValue {
	NSFont *font = [NSFont labelFontOfSize:[NSFont labelFontSize]];
	NSColor *color = [NSColor controlTextColor];
	NSDictionary *attributes = @{ NSFontAttributeName: font, NSForegroundColorAttributeName: color };

	return [[NSAttributedString alloc] initWithString:[self stringValue] attributes:attributes];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSRect cellFrameRect = cellFrame;

	static CGFloat TEXT_PADDING = 6;
	NSRect textFrame;
	CGSize stringSize = self.attributedStringValue.size;
	if (self.orientation == MBTableHeaderHorizontalOrientation) {
		textFrame = NSMakeRect(cellFrameRect.origin.x + TEXT_PADDING, cellFrameRect.origin.y + (cellFrameRect.size.height - stringSize.height)/2, cellFrameRect.size.width - TEXT_PADDING, stringSize.height);
	} else {
		textFrame = NSMakeRect(cellFrameRect.origin.x + (cellFrameRect.size.width - stringSize.width)/2, cellFrameRect.origin.y + (cellFrameRect.size.height - stringSize.height)/2, stringSize.width, stringSize.height);
	}

	[[NSGraphicsContext currentContext] saveGraphicsState];

	NSShadow *textShadow = [[NSShadow alloc] init];
	[textShadow setShadowOffset:NSMakeSize(0,-1)];
	[textShadow setShadowBlurRadius:0.0];
	[textShadow setShadowColor:[NSColor colorWithDeviceWhite:1.0 alpha:0.8]];
	[textShadow set];

	[self.attributedStringValue drawWithRect:textFrame options:NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin];
	
	[[NSGraphicsContext currentContext] restoreGraphicsState];
	
	//NSRect sortIndicatorRect = [self sortIndicatorRectForBounds:cellFrame];
	//[self.sortIndicatorImage drawInRect:sortIndicatorRect];
	
}

@end
