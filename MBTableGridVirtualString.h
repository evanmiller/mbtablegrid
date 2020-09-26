//
//  MBTableGridVirtualString.h
//  MBTableGrid
//
//  Created by Evan Miller on 1/17/20.
//

#import <Foundation/Foundation.h>

@class MBTableGrid;

@interface MBTableGridVirtualString : NSString {
    MBTableGrid *_tableGrid;
}

- (instancetype)initWithTableGrid:(MBTableGrid *)tableGrid;

@end
