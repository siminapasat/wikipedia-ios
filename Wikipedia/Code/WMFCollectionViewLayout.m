#import "WMFCollectionViewLayout.h"
#import "WMFCVLInfo.h"
#import "WMFCVLColumn.h"
#import "WMFCVLSection.h"
#import "WMFCVLAttributes.h"
#import "WMFCVLInvalidationContext.h"

@interface WMFCollectionViewLayout ()

@property (nonatomic, readonly) id <WMFCollectionViewLayoutDelegate> delegate;
@property (nonatomic) CGFloat interColumnSpacing;
@property (nonatomic) CGFloat interSectionSpacing;
@property (nonatomic) CGFloat interItemSpacing;

@property (nonatomic) UIEdgeInsets contentInsets;
@property (nonatomic) UIEdgeInsets sectionInsets;

@property (nonatomic) CGSize layoutSize;

@property (nonatomic) NSInteger numberOfColumns;
@property (nonatomic, copy) NSArray *columnWeights;
@property (nonatomic, readonly) NSInteger numberOfSections;


@property (nonatomic, strong) WMFCVLInfo *info;
@property (nonatomic, strong) WMFCVLInfo *oldInfo;

@property (nonatomic) BOOL needsLayout;

@end

@implementation WMFCollectionViewLayout

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup {
    BOOL isPad = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
    self.needsLayout = YES;
    self.numberOfColumns = isPad ? 2 : 1;
    self.columnWeights = isPad ? @[@1, @1] : @[@1];
    self.interColumnSpacing = isPad ? 22 : 0;
    self.interItemSpacing = 1;
    self.interSectionSpacing = isPad ? 22 : 50;
    self.contentInsets = isPad ? UIEdgeInsetsMake(22, 22, 22, 22) : UIEdgeInsetsMake(0, 0, 50, 0);
    self.sectionInsets = UIEdgeInsetsMake(1, 0, 1, 0);
}

#pragma mark - Properties

- (id <WMFCollectionViewLayoutDelegate>)delegate {
    assert(self.collectionView.delegate == nil || [self.collectionView.delegate conformsToProtocol:@protocol(WMFCollectionViewLayoutDelegate)]);
    return (id <WMFCollectionViewLayoutDelegate>)self.collectionView.delegate;
}

- (NSInteger)numberOfSections {
    return [self.collectionView.dataSource numberOfSectionsInCollectionView:self.collectionView];
}

- (NSInteger)numberOfItemsInSection:(NSInteger)section {
    return [self.collectionView.dataSource collectionView:self.collectionView numberOfItemsInSection:section];
}

+ (Class)invalidationContextClass {
    return [WMFCVLInvalidationContext class];
}

+ (Class)layoutAttributesClass {
    return [WMFCVLAttributes class];
}

- (CGSize)collectionViewContentSize {
    return self.layoutSize;
}


- (void)resetLayout {
    self.oldInfo = self.info;
    self.info = [[WMFCVLInfo alloc] initWithNumberOfColumns:self.numberOfColumns numberOfSections:self.numberOfSections];
}

- (void)layoutForBoundsSize:(CGSize)size {
    if (self.delegate == nil) {
        return;
    }
    
    [self resetLayout];
    
    CGFloat availableWidth = size.width - self.contentInsets.left - self.contentInsets.right - ((self.numberOfColumns - 1) * self.interColumnSpacing);
    
    CGFloat baselineColumnWidth = floor(availableWidth/self.numberOfColumns);
    
    self.info.boundsSize = size;
    
    __block NSInteger currentColumnIndex = 0;
    __block WMFCVLColumn *currentColumn = self.info.columns[currentColumnIndex];
    
    [self.info enumerateSectionsWithBlock:^(WMFCVLSection * _Nonnull section, NSUInteger sectionIndex, BOOL * _Nonnull stop) {
        currentColumn.width = [self.columnWeights[currentColumnIndex] doubleValue]*baselineColumnWidth;
        CGFloat columnWidth = currentColumn.width;
        
        CGFloat x = self.contentInsets.left;
        for (NSInteger i = 0; i < currentColumnIndex; i++) {
            x += [self.columnWeights[i] doubleValue] * baselineColumnWidth + self.interColumnSpacing;
        }
        
        if (sectionIndex == 0) {
            currentColumn.height += self.contentInsets.top;
        } else {
            currentColumn.height += self.interSectionSpacing;
        }
        CGFloat y = currentColumn.height;
        CGPoint sectionOrigin = CGPointMake(x, y);
        
        
        
        [currentColumn addSection:section];
        
        CGFloat sectionHeight = 0;
        
        CGFloat headerHeight = [self.delegate collectionView:self.collectionView estimatedHeightForHeaderInSection:sectionIndex forColumnWidth:columnWidth];
        
        
        NSIndexPath *supplementaryViewIndexPath = [NSIndexPath indexPathForRow:0 inSection:sectionIndex];
        
        WMFCVLAttributes *headerAttributes = (WMFCVLAttributes *)[WMFCVLAttributes layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionHeader withIndexPath:supplementaryViewIndexPath];
        if (headerAttributes != nil) {
            headerAttributes.frame = CGRectMake(x, y, columnWidth, headerHeight);
            [section addHeader:headerAttributes];
        }
    
        sectionHeight += headerHeight;
        y += headerHeight;
        
        CGFloat itemX = x + self.sectionInsets.left;
        CGFloat itemWidth = columnWidth - self.sectionInsets.left - self.sectionInsets.right;
        for (NSInteger item = 0; item < [self numberOfItemsInSection:sectionIndex]; item++) {
            if (item == 0) {
                y += self.sectionInsets.top;
            } else {
                y += self.interItemSpacing;
            }
            CGFloat itemHeight = [self.delegate collectionView:self.collectionView estimatedHeightForItemAtIndexPath:[NSIndexPath indexPathForItem:item inSection:sectionIndex] forColumnWidth:columnWidth];
            
            NSIndexPath *itemIndexPath = [NSIndexPath indexPathForItem:item inSection:sectionIndex];
            WMFCVLAttributes *itemAttributes = (WMFCVLAttributes *)[WMFCVLAttributes layoutAttributesForCellWithIndexPath:itemIndexPath];
            if (itemAttributes != nil) {
                itemAttributes.frame = CGRectMake(itemX, y, itemWidth, itemHeight);
                [section addItem:itemAttributes];
            }
            assert(itemHeight > 0);
            sectionHeight += itemHeight;
            y += itemHeight;
        }
        
        sectionHeight += self.sectionInsets.bottom;
        y += self.sectionInsets.bottom;
        
        CGFloat footerHeight = [self.delegate collectionView:self.collectionView estimatedHeightForFooterInSection:sectionIndex forColumnWidth:columnWidth];
        WMFCVLAttributes *footerAttributes = (WMFCVLAttributes *)[WMFCVLAttributes layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionFooter withIndexPath:supplementaryViewIndexPath];
        if (footerAttributes != nil) {
            footerAttributes.frame = CGRectMake(x, y, columnWidth, footerHeight);
            [section addFooter:footerAttributes];
        }
        
        sectionHeight += footerHeight;
        y+= footerHeight;
        
        section.frame = (CGRect){sectionOrigin,  CGSizeMake(columnWidth, sectionHeight)};
        
        currentColumn.height = currentColumn.height + sectionHeight;

        __block CGFloat shortestColumnHeight = CGFLOAT_MAX;
        [self.info enumerateColumnsWithBlock:^(WMFCVLColumn * _Nonnull column, NSUInteger idx, BOOL * _Nonnull stop) {
            CGFloat columnHeight = column.height;
            if (columnHeight < shortestColumnHeight) { //switch to the shortest column
                currentColumnIndex = idx;
                currentColumn = column;
                shortestColumnHeight = columnHeight;
            }
        }];

    }];
    
    [self.info enumerateColumnsWithBlock:^(WMFCVLColumn * _Nonnull column, NSUInteger idx, BOOL * _Nonnull stop) {
        column.height += self.contentInsets.bottom;
    }];
    [self updateLayoutSizeForBoundsSize:size];
}

- (void)updateLayoutSizeForBoundsSize:(CGSize)size {
    __block CGSize newSize = size;
    newSize.height = 0;
    [self.info enumerateColumnsWithBlock:^(WMFCVLColumn * _Nonnull column, NSUInteger idx, BOOL * _Nonnull stop) {
        CGFloat columnHeight = column.height;
        if (columnHeight > newSize.height) {
            newSize.height = columnHeight;
        }
    }];
    self.layoutSize = newSize;
}

- (nullable NSArray<__kindof UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect {
    
    NSMutableArray *attributesArray = [NSMutableArray array];
    
    [self.info enumerateSectionsWithBlock:^(WMFCVLSection * _Nonnull section, NSUInteger idx, BOOL * _Nonnull stop) {
        if (CGRectIntersectsRect(section.frame, rect)) {
            [section enumerateLayoutAttributesWithBlock:^(WMFCVLAttributes *attributes, BOOL *stop) {
                if (CGRectIntersectsRect(attributes.frame, rect)) {
                    [attributesArray addObject:attributes];
                }
            }];
        }
    }];
    
    return attributesArray;
}



- (nullable UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    return [self.info layoutAttributesForItemAtIndexPath:indexPath];
}

- (nullable UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath {
    return [self.info layoutAttributesForSupplementaryViewOfKind:elementKind atIndexPath:indexPath];
}

- (nullable UICollectionViewLayoutAttributes *)layoutAttributesForDecorationViewOfKind:(NSString*)elementKind atIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

#pragma mark - Invalidation

- (void)prepareLayout {
    if (self.needsLayout) {
        [self layoutForBoundsSize:self.collectionView.bounds.size];
        self.needsLayout = NO;
    }
    [super prepareLayout];
}


- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    return newBounds.size.width != self.info.boundsSize.width;
}

- (UICollectionViewLayoutInvalidationContext *)invalidationContextForBoundsChange:(CGRect)newBounds {
    WMFCVLInvalidationContext *invalidationContext = (WMFCVLInvalidationContext *)[super invalidationContextForBoundsChange:newBounds];
    invalidationContext.boundsDidChange = YES;
    invalidationContext.newBounds = newBounds;
    [self updateLayoutForInvalidationContext:invalidationContext];
    return invalidationContext;
}

- (BOOL)shouldInvalidateLayoutForPreferredLayoutAttributes:(UICollectionViewLayoutAttributes *)preferredAttributes withOriginalAttributes:(UICollectionViewLayoutAttributes *)originalAttributes {
    return originalAttributes.representedElementCategory == UICollectionElementCategoryCell && preferredAttributes.size.height != originalAttributes.size.height;
}

- (UICollectionViewLayoutInvalidationContext *)invalidationContextForPreferredLayoutAttributes:(UICollectionViewLayoutAttributes *)preferredAttributes withOriginalAttributes:(UICollectionViewLayoutAttributes *)originalAttributes {
    WMFCVLInvalidationContext *invalidationContext = (WMFCVLInvalidationContext *)[super invalidationContextForPreferredLayoutAttributes:preferredAttributes withOriginalAttributes:originalAttributes];
    if (invalidationContext == nil) {
        invalidationContext = [WMFCVLInvalidationContext new];
    }
    invalidationContext.preferredLayoutAttributes = preferredAttributes;
    invalidationContext.originalLayoutAttributes = originalAttributes;
    [self updateLayoutForInvalidationContext:invalidationContext];
    return invalidationContext;
}

- (void)updateLayoutForInvalidationContext:(WMFCVLInvalidationContext *)context {
    if (context.boundsDidChange) {
        NSMutableArray *invalidatedItemIndexPaths = [NSMutableArray array];
        NSMutableArray *invalidatedHeaderIndexPaths = [NSMutableArray array];
        NSMutableArray *invalidatedFooterIndexPaths = [NSMutableArray array];
        [self.info enumerateSectionsWithBlock:^(WMFCVLSection * _Nonnull section, NSUInteger sectionIndex, BOOL * _Nonnull stop) {
            NSInteger i = 0;
            while (i < section.headers.count) {
                [invalidatedHeaderIndexPaths addObject:[NSIndexPath indexPathForItem:i inSection:sectionIndex]];
                i++;
            }
            
            i = 0;
            while (i < section.items.count) {
                [invalidatedItemIndexPaths addObject:[NSIndexPath indexPathForItem:i inSection:sectionIndex]];
                i++;
            }
            
            i = 0;
            while (i < section.footers.count) {
                [invalidatedFooterIndexPaths addObject:[NSIndexPath indexPathForItem:i inSection:sectionIndex]];
                i++;
            }
        }];
        [context invalidateSupplementaryElementsOfKind:UICollectionElementKindSectionHeader atIndexPaths:invalidatedHeaderIndexPaths];
        [context invalidateItemsAtIndexPaths:invalidatedItemIndexPaths];
        [context invalidateSupplementaryElementsOfKind:UICollectionElementKindSectionFooter atIndexPaths:invalidatedFooterIndexPaths];
        [self layoutForBoundsSize:context.newBounds.size];
        self.needsLayout = NO;
    } else if (context.originalLayoutAttributes && context.preferredLayoutAttributes) {
        UICollectionViewLayoutAttributes *originalAttributes = context.originalLayoutAttributes;
        UICollectionViewLayoutAttributes *preferredAttributes = context.preferredLayoutAttributes;
        NSIndexPath *indexPath = originalAttributes.indexPath;
        
        WMFCVLSection *invalidatedSection = self.info.sections[indexPath.section];
        WMFCVLColumn *invalidatedColumn = invalidatedSection.column;
        
        CGSize sizeToSet = preferredAttributes.frame.size;
        sizeToSet.width = invalidatedColumn.width;
        [invalidatedColumn setSize:sizeToSet forItemAtIndexPath:indexPath invalidationContext:context];
        
        [self updateLayoutSizeForBoundsSize:self.layoutSize];
        
        CGSize contentSizeAdjustment = CGSizeMake(0, self.layoutSize.height - self.collectionView.contentSize.height);
        context.contentSizeAdjustment = contentSizeAdjustment;
    }
}

- (void)invalidateLayoutWithContext:(WMFCVLInvalidationContext *)context {
    assert([context isKindOfClass:[WMFCVLInvalidationContext class]]);
    if (context.invalidateEverything || context.invalidateDataSourceCounts) {
        self.needsLayout = YES;
    }
    [super invalidateLayoutWithContext:context];
}
@end
