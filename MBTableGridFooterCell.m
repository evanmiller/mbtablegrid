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

#import "MBTableGridFooterCell.h"

@implementation MBTableGridFooterCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	
	NSColor *sideColor = [NSColor colorWithDeviceWhite:1.0 alpha:0.4];
	NSColor *borderColor = [NSColor colorWithDeviceWhite:0.8 alpha:1.0];
	
	// Draw the side bevels
	NSRect sideLine = NSMakeRect(NSMinX(cellFrame), NSMinY(cellFrame), 1.0, NSHeight(cellFrame));
	[sideColor set];
	[[NSBezierPath bezierPathWithRect:sideLine] fill];
	sideLine.origin.x = NSMaxX(cellFrame)-2.0;
	[[NSBezierPath bezierPathWithRect:sideLine] fill];
	
	// Draw the right border
	NSRect borderLine = NSMakeRect(NSMaxX(cellFrame)-1, NSMinY(cellFrame), 1.0, NSHeight(cellFrame));
	[borderColor set];
	NSRectFill(borderLine);
	
	// Draw the bottom border
	NSRect bottomLine = NSMakeRect(NSMinX(cellFrame), NSMaxY(cellFrame)-1.0, NSWidth(cellFrame), 1.0);
	NSRectFill(bottomLine);

	// Draw the top border
	NSRect topLine = NSMakeRect(NSMinX(cellFrame), 0, NSWidth(cellFrame), 1.0);
	NSRectFill(topLine);

	
	if([self state] == NSOnState) {
		NSBezierPath *path = [NSBezierPath bezierPathWithRect:cellFrame];
		NSColor *overlayColor = [[NSColor alternateSelectedControlColor] colorWithAlphaComponent:0.2];
		[overlayColor set];
		[path fill];
	}
	
	// Draw the text
	[self drawInteriorWithFrame:cellFrame inView:controlView];
}

- (NSAttributedString *)attributedStringValue {
	NSFont *font = [NSFont labelFontOfSize:[NSFont labelFontSize]];
	NSColor *color = [NSColor controlTextColor];
	NSDictionary *attributes = @{ NSFontAttributeName: font, NSForegroundColorAttributeName: color };

	return [[NSAttributedString alloc] initWithString:[self stringValue] attributes:attributes];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	static CGFloat TEXT_PADDING = 6;
	NSRect textFrame;
	CGSize stringSize = self.attributedStringValue.size;
	textFrame = NSMakeRect(cellFrame.origin.x + TEXT_PADDING, cellFrame.origin.y + (cellFrame.size.height - stringSize.height)/2, cellFrame.size.width - TEXT_PADDING, stringSize.height);

	[[NSGraphicsContext currentContext] saveGraphicsState];

	NSShadow *textShadow = [[NSShadow alloc] init];
	[textShadow setShadowOffset:NSMakeSize(0,-1)];
	[textShadow setShadowBlurRadius:0.0];
	[textShadow setShadowColor:[NSColor colorWithDeviceWhite:1.0 alpha:0.8]];
	[textShadow set];

	[self.attributedStringValue drawWithRect:textFrame options:NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin];
	
	[[NSGraphicsContext currentContext] restoreGraphicsState];
	
}



@end
