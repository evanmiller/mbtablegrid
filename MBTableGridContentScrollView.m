//
//  MBTableGridContentScrollView.m
//  MBTableGrid
//
//  Created by Evan Miller on 1/17/20.
//

#import "MBTableGridContentScrollView.h"

@implementation MBTableGridContentScrollView

+ (void)huntDownAndHideSearchFieldMenuItemsInView:(NSView *)v {
    if ([v isKindOfClass:[NSSearchField class]]) {
        NSSearchField *searchField = (NSSearchField *)v;
        for (int i=2; i<8; i++) // Cut out unsupported operations.
            [searchField.searchMenuTemplate itemAtIndex:i].hidden = YES;

        return;
    }
    for (NSView *subview in v.subviews){
        [self huntDownAndHideSearchFieldMenuItemsInView:subview];
    }
}

- (void)setFindBarVisible:(BOOL)findBarVisible {
    [super setFindBarVisible:findBarVisible];
    
    if (findBarVisible) {
        [[self class] huntDownAndHideSearchFieldMenuItemsInView:self.findBarView];
    }
}

@end
