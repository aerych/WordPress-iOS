//
//  SharePostController.m
//  WordPress
//
//  Created by Eric J on 11/1/12.
//  Copyright (c) 2012 WordPress. All rights reserved.
//

#import "SharePostController.h"
#import "EditPostViewController.h"
#import "BlogsTableViewCell.h"
#import "UIImageView+Gravatar.h"
#import "NSString+XMLExtensions.h"
#import "Blog.h"
#import "Post.h"

@interface SharePostController ()

@property (nonatomic, strong) NSMutableDictionary *shareDict;

+ (NSMutableDictionary *)dictionaryFromURL:(NSURL *)url;
+ (void)saveImage:(UIImage *)image forPost:(Post *)post;
- (void)dismissModal:(id)sender;

@end

@implementation SharePostController

@synthesize shareDict;


+ (void)shareWithURL:(NSURL *)shareURL {
    
    // How many blogs do we have?
    
    WordPressAppDelegate *appDelegate = [WordPressAppDelegate sharedWordPressApp];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"Blog" inManagedObjectContext:appDelegate.managedObjectContext]];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"blogName" ascending:YES];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // For some reasons, the cache sometimes gets corrupted
    // Since we don't really use sections we skip the cache here
    NSFetchedResultsController *resultsController = [[NSFetchedResultsController alloc]
                                                     initWithFetchRequest:fetchRequest
                                                     managedObjectContext:appDelegate.managedObjectContext
                                                     sectionNameKeyPath:nil
                                                     cacheName:nil];
    NSError *error = nil;
    [resultsController performFetch:&error];
    
    NSUInteger numBlogs = [resultsController.fetchedObjects count];
    
    if (numBlogs == 0) {
        // Badness. Can't share until a blog has been added.
        // Do nothing.
        return;
    }
    
    UIViewController *controller = nil;
    if(numBlogs == 1) {
        // Proceed to EditPostViewController.
        Blog *blog = (Blog *)[resultsController.fetchedObjects objectAtIndex:0];
        Post *post = [Post newDraftForBlog:blog];
        
        NSDictionary *dict = [self dictionaryFromURL:shareURL];
        post.postTitle = [dict objectForKey:@"title"];
        post.tags = [dict objectForKey:@"tags"];
        post.content = [dict objectForKey:@"content"];
        UIImage *img = [[UIPasteboard generalPasteboard] image];
        if(img){
            [SharePostController saveImage:img forPost:post];
        }

        EditPostViewController *editvc = [[EditPostViewController alloc] initWithPost:[post createRevision]];
        [editvc refreshUIForCurrentPost];
        controller = editvc;

    } else {
        // Show the blog picker.
        controller = [[SharePostController alloc] initWithURL:shareURL];
        
        [controller view];
    }
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:controller];
    navController.modalPresentationStyle = UIModalPresentationPageSheet;
    [appDelegate.panelNavigationController presentModalViewController:navController animated:YES];
}


+ (NSMutableDictionary *)dictionaryFromURL:(NSURL *)url {
    NSMutableDictionary *shareDict = [NSMutableDictionary dictionary];
    NSArray *components = [[[url query] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]componentsSeparatedByString:@"&"];
    for (NSString *keyValuePair in components) {
        NSArray *pairComponents = [keyValuePair componentsSeparatedByString:@"="];
        NSString *key = [pairComponents objectAtIndex:0];
        NSString *value = [pairComponents objectAtIndex:1];
        if (value){
            value = [value stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            [shareDict setObject:value forKey:key];
        }

    }
    return shareDict;
}


+ (void)saveImage:(UIImage *)image forPost:(Post *)post {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            Media *media = nil;
            
            if (post.media && [post.media count] > 0) {
                media = [post.media anyObject];
            } else {
                media = [Media newMediaForPost:post];
                int resizePreference = 0;
                if([[NSUserDefaults standardUserDefaults] objectForKey:@"media_resize_preference"] != nil)
                    resizePreference = [[[NSUserDefaults standardUserDefaults] objectForKey:@"media_resize_preference"] intValue];
                
                MediaResize newSize = kResizeLarge;
                switch (resizePreference) {
                    case 1:
                        newSize = kResizeSmall;
                        break;
                    case 2:
                        newSize = kResizeMedium;
                        break;
                    case 4:
                        newSize = kResizeOriginal;
                        break;
                }
                
                [media setImage:image withSize:newSize];
            }
            
            [media save];
        });
    });
}


#pragma mark -
#pragma mark LifeCycle Methods

- (id)initWithURL:(NSURL *)shareURL {

    self = [self initWithStyle:UITableViewStylePlain];
    if(self) {
        self.shareDict = [SharePostController dictionaryFromURL:shareURL];
    }
    
    return self;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Share to Blog";
    // Add cancel button.
    UIBarButtonItem *leftButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                target:self
                                                                                action:@selector(dismissModal:)];
    self.navigationItem.leftBarButtonItem = leftButton;
    
}


- (void)dismissModal:(id)sender {
    [self dismissModalViewControllerAnimated:YES];
}


- (NSUInteger)tableView:tableView heightForHeaderInSection:(NSInteger)section {
    return 44.0f;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return NSLocalizedString(@"To which blog are you sharing?", @"");
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    Blog *blog = [resultsController objectAtIndexPath:indexPath];
    
    Post *post = [Post newDraftForBlog:blog];
    post.postTitle = [self.shareDict objectForKey:@"title"];
    post.tags = [self.shareDict objectForKey:@"tags"];
    post.content = [self.shareDict objectForKey:@"content"];
    
    UIImage *img = [[UIPasteboard generalPasteboard] image];
    if(img){
        [SharePostController saveImage:img forPost:post];
    }

    EditPostViewController *controller = [[EditPostViewController alloc] initWithPost:[post createRevision]];
    [controller view];
    [controller refreshUIForCurrentPost];
    [self.navigationController setViewControllers:[NSArray arrayWithObject:controller] animated:YES];
}





@end
