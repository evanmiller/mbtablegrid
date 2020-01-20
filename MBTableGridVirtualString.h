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

- (id)initWithTableGrid:(MBTableGrid *)tableGrid;

@end
