//
//  SharePostController.h
//  WordPress
//
//  Created by Eric J on 11/1/12.
//  Copyright (c) 2012 WordPress. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BlogSelectorViewController.h"

@interface SharePostController : BlogSelectorViewController

+ (void)shareWithURL:(NSURL *)shareURL;
- (id)initWithURL:(NSURL *)shareURL;

@end
