//
//  NSScrollView+InsetRectangles.m
//  MBTableGrid
//
//  Created by Evan Miller on 1/23/20.
//

#import "NSScrollView+InsetRectangles.h"

#import <AppKit/AppKit.h>

@implementation NSScrollView (InsetRectangles)

- (NSRect)_insetRectForRect:(NSRect)visibleRect {
    // Account for contentInsets, e.g. if the enclosing view overlays an NSVisualEffectView
    visibleRect.origin.y += self.contentInsets.top;
    visibleRect.size.height -= (self.contentInsets.bottom + self.contentInsets.top);

    visibleRect.origin.x += self.contentInsets.left;
    visibleRect.size.width -= (self.contentInsets.left + self.contentInsets.right);
    
    return visibleRect;
}

- (NSRect)insetDocumentVisibleRect {
    return [self _insetRectForRect:self.documentVisibleRect];
}

- (NSRect)insetFrame {
    return [self _insetRectForRect:self.frame];
}

@end
