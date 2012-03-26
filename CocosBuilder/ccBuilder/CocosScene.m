/*
 * CocosBuilder: http://www.cocosbuilder.com
 *
 * Copyright (c) 2011 Viktor Lidholt
 * Copyright (c) 2012 Zynga Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import "CocosScene.h"
#import "CCBGlobals.h"
#import "CocosBuilderAppDelegate.h"
#import "CCBReaderInternalV1.h"
#import "NodeInfo.h"
#import "PlugInManager.h"
#import "PlugInNode.h"

@implementation CocosScene

@synthesize rootNode, isMouseTransforming, scrollOffset, currentTool;

+(id) sceneWithAppDelegate:(CocosBuilderAppDelegate*)app
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	CocosScene *layer = [[[CocosScene alloc] initWithAppDelegate:app] autorelease];
    [[CCBGlobals globals] setCocosScene:layer];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

-(void) setupEditorNodes
{
    // Selection layer
    selectionLayer = [CCLayer node];
    [self addChild:selectionLayer z:2];
    
    // Border layer
    borderLayer = [CCLayer node];
    [self addChild:borderLayer z:1];
    
    ccColor4B borderColor = ccc4(128, 128, 128, 180);
    
    borderBottom = [CCLayerColor layerWithColor:borderColor];
    borderTop = [CCLayerColor layerWithColor:borderColor];
    borderLeft = [CCLayerColor layerWithColor:borderColor];
    borderRight = [CCLayerColor layerWithColor:borderColor];
    
    [borderLayer addChild:borderBottom];
    [borderLayer addChild:borderTop];
    [borderLayer addChild:borderLeft];
    [borderLayer addChild:borderRight];
    
    borderDeviceIPhone = [CCSprite spriteWithFile:@"frame-iphone.png"];
    borderDeviceIPad = [CCSprite spriteWithFile:@"frame-ipad.png"];
    [borderLayer addChild:borderDeviceIPhone z:1];
    [borderLayer addChild:borderDeviceIPad z:1];
    
    // Gray background
    bgLayer = [CCLayerColor layerWithColor:ccc4(128, 128, 128, 255) width:4096 height:4096];
    bgLayer.position = ccp(0,0);
    bgLayer.anchorPoint = ccp(0,0);
    [self addChild:bgLayer z:-1];
    
    // Black content layer
    stageBgLayer = [CCLayerColor layerWithColor:ccc4(0, 0, 0, 255) width:0 height:0];
    stageBgLayer.anchorPoint = ccp(0.5,0.5);
    stageBgLayer.isRelativeAnchorPoint = YES;
    [self addChild:stageBgLayer z:0];
    
    contentLayer = [CCLayer node];
    [stageBgLayer addChild:contentLayer];
}

- (void) setStageBorder:(int)type
{
    borderDeviceIPhone.visible = NO;
    borderDeviceIPad.visible = NO;
    
    if (type == kCCBBorderDevice)
    {
        [borderBottom setOpacity:255];
        [borderTop setOpacity:255];
        [borderLeft setOpacity:255];
        [borderRight setOpacity:255];
        
        int devType = [appDelegate orientedDeviceTypeForSize:stageBgLayer.contentSize];
        if (devType == kCCBCanvasSizeIPhonePortrait)
        {
            borderDeviceIPhone.visible = YES;
            borderDeviceIPhone.rotation = 0;
            
        }
        else if (devType == kCCBCanvasSizeIPhoneLandscape)
        {
            borderDeviceIPhone.visible = YES;
            borderDeviceIPhone.rotation = 90;
        }
        else if (devType == kCCBCanvasSizeIPadPortrait)
        {
            borderDeviceIPad.visible = YES;
            borderDeviceIPad.rotation = 0;
        }
        else if (devType == kCCBCanvasSizeIPadLandscape)
        {
            borderDeviceIPad.visible = YES;
            borderDeviceIPad.rotation = 90;
        }
    }
    else if (type == kCCBBorderTransparent)
    {
        [borderBottom setOpacity:180];
        [borderTop setOpacity:180];
        [borderLeft setOpacity:180];
        [borderRight setOpacity:180];
    }
    else if (type == kCCBBorderOpaque)
    {
        [borderBottom setOpacity:255];
        [borderTop setOpacity:255];
        [borderLeft setOpacity:255];
        [borderRight setOpacity:255];
    }
    else
    {
        [borderBottom setOpacity:0];
        [borderTop setOpacity:0];
        [borderLeft setOpacity:0];
        [borderRight setOpacity:0];
    }
    
    stageBorderType = type;
}

- (int) stageBorder
{
    return stageBorderType;
}

- (void) setupDefaultNodes
{
}

#pragma mark Stage properties

- (void) setStageSize: (CGSize) size centeredOrigin:(BOOL)centeredOrigin
{
    stageBgLayer.contentSize = size;
    if (centeredOrigin) contentLayer.position = ccp(size.width/2, size.height/2);
    else contentLayer.position = ccp(0,0);
    
    [self setStageBorder:stageBorderType];
    
    if (renderedScene)
    {
        [self removeChild:renderedScene cleanup:YES];
        renderedScene = NULL;
    }
    
    if (size.width > 0 && size.height > 0 && size.width <= 1024 && size.height <= 1024)
    {
        CCGLView *view = [[CCDirector sharedDirector] view];
        NSOpenGLContext *glContext = [view openGLContext];
        if( ! glContext )
            return;        
        CGLLockContext([glContext CGLContextObj]);	
        [glContext makeCurrentContext];

        
        renderedScene = [CCRenderTexture renderTextureWithWidth:size.width height:size.height];
        renderedScene.anchorPoint = ccp(0.5f,0.5f);
        [self addChild:renderedScene];
        
        
        CGLUnlockContext( [glContext CGLContextObj] );
    }
}

- (CGSize) stageSize
{
    return stageBgLayer.contentSize;
}

- (BOOL) centeredOrigin
{
    return (contentLayer.position.x != 0);
}

- (void) setStageZoom:(float) zoom
{
    float zoomFactor = zoom/stageZoom;
    
    scrollOffset = ccpMult(scrollOffset, zoomFactor);
    
    stageBgLayer.scale = zoom;
    borderDeviceIPad.scale = zoom;
    borderDeviceIPhone.scale = zoom;
    
    stageZoom = zoom;
}

- (float) stageZoom
{
    return stageZoom;
}

#pragma mark Extra properties

- (id) extraPropForKey:(NSString*)key andNode:(CCNode*) node
{
    NodeInfo* info = node.userObject;
    return [info.extraProps objectForKey:key];
}

- (void) setExtraProp: (id)val forKey:(NSString*)key andNode:(CCNode*) node
{
    NodeInfo* info = node.userObject;
    [info.extraProps setObject:val forKey:key];
}


- (void) setupExtraPropsForNode:(CCNode*) node
{
    [self setExtraProp:[NSNumber numberWithInt:-1] forKey:@"tag" andNode:node];
    [self setExtraProp:[NSNumber numberWithBool:YES] forKey:@"lockedScaleRatio" andNode:node];
    
    [self setExtraProp:@"" forKey:@"customClass" andNode:node];
    [self setExtraProp:[NSNumber numberWithInt:0] forKey:@"memberVarAssignmentType" andNode:node];
    [self setExtraProp:@"" forKey:@"memberVarAssignmentName" andNode:node];
    
    [self setExtraProp:[NSNumber numberWithBool:YES] forKey:@"isExpanded" andNode:node];
}

#pragma mark Replacing content

- (void) replaceRootNodeWith:(CCNode*)node
{
    CCBGlobals* g = [CCBGlobals globals];
    
    [contentLayer removeChild:rootNode cleanup:YES];
    
    self.rootNode = node;
    g.rootNode = node;
    
    if (!node) return;
    
    [contentLayer addChild:node];
}

#pragma mark Handle selections

- (void) setSelectedNode:(CCNode*) node
{
    selectedNode = node;
    
    [self updateSelection];
}

- (void) updateSelection
{
    CCNode* node = selectedNode;
    
    // Clear selection
    [selectionLayer removeAllChildrenWithCleanup:YES];
    
    if (node)
    {
        CCNode* parent = node.parent;
        
        // Add centerpoint
        CGPoint center = [parent convertToWorldSpace: node.position];
        CCSprite* selmarkCenter = [CCSprite spriteWithFile:@"select-pt.png"];
        selmarkCenter.position = center;
        [selectionLayer addChild:selmarkCenter];
        
        CGPoint minCorner = center;
        
        if (node.contentSize.width > 0 && node.contentSize.height > 0)
        {
            CGAffineTransform transform = [node nodeToWorldTransform];
            float angle = -(atan2(transform.b, transform.a)/(M_PI*2))*360;
            
            // Add bounding box markers
            CGPoint bl = [node convertToWorldSpace: ccp(0,0)];
            CCSprite* blSelmark = [CCSprite spriteWithFile:@"select-bl.png"];
            blSelmark.position = bl;
            blSelmark.rotation = angle;
            [selectionLayer addChild:blSelmark];
            
            CGPoint br = [node convertToWorldSpace: ccp(node.contentSize.width,0)];
            CCSprite* brSelmark = [CCSprite spriteWithFile:@"select-br.png"];
            brSelmark.position = br;
            brSelmark.rotation = angle;
            [selectionLayer addChild:brSelmark];
            
            CGPoint tl = [node convertToWorldSpace: ccp(0,node.contentSize.height)];
            CCSprite* tlSelmark = [CCSprite spriteWithFile:@"select-tl.png"];
            tlSelmark.position = tl;
            tlSelmark.rotation = angle;
            [selectionLayer addChild:tlSelmark];
            
            CGPoint tr = [node convertToWorldSpace: ccp(node.contentSize.width,node.contentSize.height)];
            CCSprite* trSelmark = [CCSprite spriteWithFile:@"select-tr.png"];
            trSelmark.position = tr;
            trSelmark.rotation = angle;
            [selectionLayer addChild:trSelmark];
            
            minCorner.x = MIN(minCorner.x, bl.x);
            minCorner.x = MIN(minCorner.x, br.x);
            minCorner.x = MIN(minCorner.x, tl.x);
            minCorner.x = MIN(minCorner.x, tr.x);
            
            minCorner.y = MIN(minCorner.y, bl.y);
            minCorner.y = MIN(minCorner.y, br.y);
            minCorner.y = MIN(minCorner.y, tl.y);
            minCorner.y = MIN(minCorner.y, tr.y);
        }
        
        if (minCorner.x < 10) minCorner.x = 10;
        if (minCorner.y < 36) minCorner.y = 36;
        if (minCorner.x > self.contentSize.width - 28*3+6) minCorner.x = self.contentSize.width - 28*3+6;
        if (minCorner.y > self.contentSize.height+6) minCorner.y = self.contentSize.height+6;
        
        minCorner.x = (int)minCorner.x;
        minCorner.y = (int)minCorner.y;
        
        if (currentMouseTransform == kCCBTransformHandleNone ||
            currentMouseTransform == kCCBTransformHandleMove)
        {
            rectBtnMove = CGRectMake(minCorner.x-8, minCorner.y-36, 28, 28);
            rectBtnScale = CGRectMake(minCorner.x-8+28, minCorner.y-36, 28, 28);
            rectBtnRotate = CGRectMake(minCorner.x-8+56, minCorner.y-36, 28, 28);
        }
        
        // Move handle
        CCSprite* btnMove;
        if (currentMouseTransform == kCCBTransformHandleMove) btnMove = [CCSprite spriteWithFile:@"btn-move-hi.png"];
        else btnMove = [CCSprite spriteWithFile:@"btn-move.png"];
        
        btnMove.position = rectBtnMove.origin;
        btnMove.anchorPoint = ccp(0,0);
        [selectionLayer addChild:btnMove z:1];
        
        // Scale handle
        CCSprite* btnScale;
        if (currentMouseTransform == kCCBTransformHandleScale) btnScale = [CCSprite spriteWithFile:@"btn-scale-hi.png"];
        else btnScale = [CCSprite spriteWithFile:@"btn-scale.png"];
        
        btnScale.position = rectBtnScale.origin;
        btnScale.anchorPoint = ccp(0,0);
        [selectionLayer addChild:btnScale z:1];
        
        // Rotation handle
        CCSprite* btnRotate;
        if (currentMouseTransform == kCCBTransformHandleRotate) btnRotate = [CCSprite spriteWithFile:@"btn-rotate-hi.png"];
        else btnRotate = [CCSprite spriteWithFile:@"btn-rotate.png"];
        
        btnRotate.position = rectBtnRotate.origin;
        btnRotate.anchorPoint = ccp(0,0);
        [selectionLayer addChild:btnRotate z:1];
    }
}

- (void) selectBehind
{
    if (currentNodeAtSelectionPtIdx < 0) return;
    
    currentNodeAtSelectionPtIdx -= 1;
    if (currentNodeAtSelectionPtIdx < 0)
    {
        currentNodeAtSelectionPtIdx = (int)[nodesAtSelectionPt count] -1;
    }
    
    [appDelegate setSelectedNode:[nodesAtSelectionPt objectAtIndex:currentNodeAtSelectionPtIdx]];
}

#pragma mark Handle mouse input

- (int) transformHandleUnderPt:(CGPoint)pt
{
    if (!selectedNode) return kCCBTransformHandleNone;
    
    if (CGRectContainsPoint(rectBtnMove, pt)) return kCCBTransformHandleMove;
    else if (CGRectContainsPoint(rectBtnScale, pt)) return kCCBTransformHandleScale;
    else if (CGRectContainsPoint(rectBtnRotate, pt)) return kCCBTransformHandleRotate;
    else return kCCBTransformHandleNone;
}

- (void) nodesUnderPt:(CGPoint)pt rootNode:(CCNode*) node nodes:(NSMutableArray*)nodes
{
    if (!node) return;
    
    NodeInfo* parentInfo = node.parent.userObject;
    PlugInNode* parentPlugIn = parentInfo.plugIn;
    
    if (parentPlugIn && !parentPlugIn.canHaveChildren) return;
    
    CGRect hitRect = [node boundingBox];
    
    // Extend the hit area if it's too small
    if (node.contentSize.width < 10)
    {
        hitRect.origin.x -= 5;
        hitRect.size.width += 10;
    }
    
    if (node.contentSize.height < 10)
    {
        hitRect.origin.y -= 5;
        hitRect.size.height += 10;
    }
    
    CCNode* parent = node.parent;
    CGPoint ptLocal = [parent convertToNodeSpace:pt];
    
    if (CGRectContainsPoint(hitRect, ptLocal))
    {
        [nodes addObject:node];
    }
    
    // Visit children
    for (int i = 0; i < [node.children count]; i++)
    {
        [self nodesUnderPt:pt rootNode:[node.children objectAtIndex:i] nodes:nodes];
    }
    
}

- (BOOL) ccMouseDown:(NSEvent *)event
{
    NSPoint posRaw = [event locationInWindow];
    CGPoint pos;
    pos.x = posRaw.x;
    pos.y = posRaw.y;
    pos.x -= [appDelegate.cocosView frame].origin.x;
    pos.y -= [appDelegate.cocosView frame].origin.y;
    
    mouseDownPos = pos;
    
    if (currentTool == kCCBToolGrab || ([event modifierFlags] & NSCommandKeyMask))
    {
        [[NSCursor closedHandCursor] push];
        isPanning = YES;
        panningStartScrollOffset = scrollOffset;
        return YES;
    }
    
    // Check for clicked transform handles
    int th = [self transformHandleUnderPt:pos];
    if (th)
    {
        if (th == kCCBTransformHandleMove)
        {
            transformStartPosition = [selectedNode.parent convertToWorldSpace:selectedNode.position];
        }
        else if (th == kCCBTransformHandleScale)
        {
            transformStartScaleX = selectedNode.scaleX;
            transformStartScaleY = selectedNode.scaleY;
        }
        else if (th == kCCBTransformHandleRotate)
        {
            transformStartRotation = selectedNode.rotation;
        }
        currentMouseTransform = th;
        
        return YES;
    }
    
    [nodesAtSelectionPt removeAllObjects];
    [self nodesUnderPt:pos rootNode:rootNode nodes:nodesAtSelectionPt];
    currentNodeAtSelectionPtIdx = (int)[nodesAtSelectionPt count] -1;
    if (currentNodeAtSelectionPtIdx >= 0)
    {
        [appDelegate setSelectedNode:[nodesAtSelectionPt objectAtIndex:currentNodeAtSelectionPtIdx]];
    }
    else
    {
        [appDelegate setSelectedNode:NULL];
    }
    
    return YES;
}

- (BOOL) ccMouseDragged:(NSEvent *)event
{
    NSPoint posRaw = [event locationInWindow];
    CGPoint pos;
    pos.x = posRaw.x; pos.y = posRaw.y;
    pos.x -= [appDelegate.cocosView frame].origin.x;
    pos.y -= [appDelegate.cocosView frame].origin.y;
    
    if (currentMouseTransform == kCCBTransformHandleMove)
    {
        float xDelta = pos.x - mouseDownPos.x;
        float yDelta = pos.y - mouseDownPos.y;
        
        CGPoint newPos = ccp(transformStartPosition.x+xDelta, transformStartPosition.y+yDelta);
        CGPoint newLocalPos = [selectedNode.parent convertToNodeSpace:newPos];
        
        [appDelegate saveUndoStateWillChangeProperty:@"position"];
        appDelegate.selectedNode.position = newLocalPos;
        [appDelegate refreshProperty:@"position"];
    }
    else if (currentMouseTransform == kCCBTransformHandleScale)
    {
        float xDelta = pos.x - mouseDownPos.x;
        float delta = xDelta;
        
        [appDelegate saveUndoStateWillChangeProperty:@"scale"];
        appDelegate.selectedNode.scaleX = transformStartScaleX + delta/100.0f;
        appDelegate.selectedNode.scaleY = transformStartScaleY + delta/100.0f;
        [appDelegate refreshProperty:@"scale"];
    }
    else if (currentMouseTransform == kCCBTransformHandleRotate)
    {
        float xDelta = pos.x - mouseDownPos.x;
        float delta = xDelta;
        
        [appDelegate saveUndoStateWillChangeProperty:@"rotation"];
        appDelegate.selectedNode.rotation = transformStartRotation + delta/4.0f;
        [appDelegate refreshProperty:@"rotation"];
    }
    else if (isPanning)
    {
        CGPoint delta = ccpSub(pos, mouseDownPos);
        scrollOffset = ccpAdd(panningStartScrollOffset, delta);
    }
    
    return YES;
}

- (BOOL) ccMouseUp:(NSEvent *)event
{
    isMouseTransforming = NO;
    
    if (isPanning)
    {
        [NSCursor pop];
        isPanning = NO;
    }
    
    currentMouseTransform = kCCBTransformHandleNone;
    return YES;
}

- (void) ccMouseEntered:(NSEvent*)event
{
    if (currentTool == kCCBToolGrab)
    {
        [[NSCursor openHandCursor] push];
    }
}

- (void) ccMouseExited:(NSEvent *)theEvent
{
    if (currentTool == kCCBToolGrab)
    {
        [NSCursor pop];
    }
}

- (void) scrollWheel:(NSEvent *)theEvent
{
    if (isMouseTransforming || isPanning || currentMouseTransform != kCCBTransformHandleNone) return;
    
    int dx = [theEvent deltaX]*4;
    int dy = -[theEvent deltaY]*4;
    
    scrollOffset.x = scrollOffset.x+dx;
    scrollOffset.y = scrollOffset.y+dy;
}

#pragma mark Init and dealloc

-(id) initWithAppDelegate:(CocosBuilderAppDelegate*)app;
{
    appDelegate = app;
    
    nodesAtSelectionPt = [[NSMutableArray array] retain];
    
	if( (self=[super init] ))
    {
        
        [self setupEditorNodes];
        [self setupDefaultNodes];
        
        [self schedule:@selector(nextFrame:)];
        
        self.isMouseEnabled = YES;
        
        stageZoom = 1;
	}
	return self;
}

- (void) nextFrame:(ccTime) time
{
    // Recenter the content layer
    CGSize winSize = [[CCDirector sharedDirector] winSize];
    CGPoint stageCenter = ccp((int)(winSize.width/2+scrollOffset.x) , (int)(winSize.height/2+scrollOffset.y));
    
    self.contentSize = winSize;
    
    stageBgLayer.position = stageCenter;
    renderedScene.position = stageCenter;
    
    if (stageZoom <= 1 || !renderedScene)
    {
        // Use normal rendering
        stageBgLayer.visible = YES;
        renderedScene.visible = NO;
        [[borderDeviceIPhone texture] setAntiAliasTexParameters];
        [[borderDeviceIPad texture] setAntiAliasTexParameters];
    }
    else
    {
        // Render with render-texture
        stageBgLayer.visible = NO;
        renderedScene.visible = YES;
        renderedScene.scale = stageZoom;
        [renderedScene beginWithClear:0 g:0 b:0 a:1];
        [contentLayer visit];
        [renderedScene end];
        [[borderDeviceIPhone texture] setAliasTexParameters];
        [[borderDeviceIPad texture] setAliasTexParameters];
    }
    
    [self updateSelection];
    
    // Setup border layer
    CGRect bounds = [stageBgLayer boundingBox];
    
    borderBottom.position = ccp(0,0);
    [borderBottom setContentSize:CGSizeMake(winSize.width, bounds.origin.y)];
    
    borderTop.position = ccp(0, bounds.size.height + bounds.origin.y);
    [borderTop setContentSize:CGSizeMake(winSize.width, winSize.height - bounds.size.height - bounds.origin.y)];
    
    borderLeft.position = ccp(0,bounds.origin.y);
    [borderLeft setContentSize:CGSizeMake(bounds.origin.x, bounds.size.height)];
    
    borderRight.position = ccp(bounds.origin.x+bounds.size.width, bounds.origin.y);
    [borderRight setContentSize:CGSizeMake(winSize.width - bounds.origin.x - bounds.size.width, bounds.size.height)];
    
    CGPoint center = ccp(bounds.origin.x+bounds.size.width/2, bounds.origin.y+bounds.size.height/2);
    borderDeviceIPhone.position = center;
    borderDeviceIPad.position = center;
}

- (void) dealloc
{
    [nodesAtSelectionPt release];
	[super dealloc];
}

#pragma mark Debug

- (void) printNodes:(CCNode*)node level:(int)level
{
    if ([node.parent isKindOfClass:[CCMenuItemImage class]]) return;
    if ([node.parent isKindOfClass:[CCLabelBMFont class]]) return;
    if ([node.parent isKindOfClass:[CCMenuItemFont class]]) return;
    if ([node.parent isKindOfClass:[CCMenuItemBMFont class]]) return;
    
    NSString* indent = @"";
    for (int i = 0; i < level; i++) indent = [indent stringByAppendingString:@"-"];
    
    for (int i = 0; i < [[node children] count]; i++)
    {
        [self printNodes:[[node children] objectAtIndex:i] level:level+1];
    }
    
}

- (void) printExtraProps:(CCNode*)node level:(int)level
{
    if ([node.parent isKindOfClass:[CCMenuItemImage class]]) return;
    if ([node.parent isKindOfClass:[CCLabelBMFont class]]) return;
    if ([node.parent isKindOfClass:[CCMenuItemFont class]]) return;
    if ([node.parent isKindOfClass:[CCMenuItemBMFont class]]) return;

    NSString* indent = @"";
    for (int i = 0; i < level; i++) indent = [indent stringByAppendingString:@"-"];
    
    NSLog(@"%@%@",indent,[node className]);
    NodeInfo* info = node.userObject;
    NSLog(@"%@",info.extraProps);
    
    for (int i = 0; i < [[node children] count]; i++)
    {
        [self printExtraProps:[[node children] objectAtIndex:i] level:level+1];
    }
    
}

- (void) printExtraProps
{
    [self printExtraProps:rootNode level:0];
}

- (void) printExtraPropsForNode:(CCNode*)node
{
}

@end
