//
//  NSScrollView+InsetRectangles.h
//  MBTableGrid
//
//  Created by Evan Miller on 1/23/20.
//

#import <AppKit/AppKit.h>


#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSScrollView (InsetRectangles)

@property (nonatomic, readonly) NSRect insetDocumentVisibleRect;
@property (nonatomic, readonly) NSRect insetFrame;
@property (nonatomic, readonly) NSRect insetBounds;
@property (nonatomic, readonly) NSRect insetContentViewBounds;

@end

NS_ASSUME_NONNULL_END
