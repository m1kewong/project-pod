import { Response } from 'express';
import { AuthenticatedRequest } from '../middleware/auth.middleware';
import { firebaseService } from '../services/firebase.service';
import { cacheService } from '../services/cache.service';
import { FieldValue } from '../services/firebase.service';
import { logger } from '../utils/logger';
import { NotFoundError, ForbiddenError, ValidationError } from '../utils/errors';
import { asyncHandler } from '../middleware/error.middleware';
import { v4 as uuidv4 } from 'uuid';

export class CommentController {
  private get firestore() {
    return firebaseService.getFirestore();
  }
  // Get comments for a video
  public getComments = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
    const { videoId } = req.params;
    const { page = 1, limit = 20, sort = 'date', order = 'desc' } = req.query;
    const userId = req.user?.uid;

    const cacheKey = `comments:${videoId}:${sort}:${order}:${page}:${limit}`;
    const cachedComments = await cacheService.get(cacheKey);
    
    if (cachedComments) {
      return res.json({
        success: true,
        data: cachedComments,
        cached: true
      });
    }

    // Validate video exists
    if (!videoId) {
      throw new ValidationError('Video ID is required');
    }    const videoDoc = await this.firestore.collection('videos').doc(videoId).get();
    if (!videoDoc.exists) {
      throw new NotFoundError('Video not found');
    }

    // Query comments
    let query = this.firestore
      .collection('comments')
      .where('videoId', '==', videoId)
      .where('parentId', '==', null);

    // Apply sorting
    if (sort === 'likes') {
      query = query.orderBy('likeCount', order as any);
    } else {
      query = query.orderBy('createdAt', order as any);
    }

    const pageNum = Number(page);
    const limitNum = Number(limit);
    const offset = (pageNum - 1) * limitNum;

    const commentsSnapshot = await query.offset(offset).limit(limitNum).get();

    // Get user data for all comments
    const comments = await Promise.all(
      commentsSnapshot.docs.map(async (doc: any) => {
        const commentData = doc.data();
        let userData = null;
        let isLiked = false;        // Get user data
        try {
          const userDoc = await this.firestore.collection('users').doc(commentData['userId']).get();
          userData = userDoc.data();
        } catch (error) {
          logger.warn(`Failed to get user data for comment ${doc.id}`, error);
        }

        // Check if current user liked this comment
        if (userId) {
          const likeDoc = await this.firestore
            .collection('comment_likes')
            .doc(`${doc.id}_${userId}`)
            .get();
          isLiked = likeDoc.exists;
        }

        return {
          id: doc.id,
          content: commentData['content'],
          likeCount: commentData['likeCount'] || 0,
          replyCount: 0, // Will be calculated separately if needed
          createdAt: commentData['createdAt'],
          updatedAt: commentData['updatedAt'],
          isLiked,
          user: {
            uid: userData?.['uid'] || commentData['userId'],
            displayName: userData?.['displayName'] || 'Unknown User',
            username: userData?.['username'],
            profilePicture: userData?.['profilePicture'],
          },
        };
      })
    );

    const result = {
      comments,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total: commentsSnapshot.size,
        hasMore: commentsSnapshot.size === limitNum
      }
    };

    // Cache the result
    await cacheService.set(cacheKey, result, 300); // 5 minutes

    return res.json({
      success: true,
      data: result
    });
  });

  // Get replies for a comment
  public getReplies = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
    const { commentId } = req.params;
    const { page = 1, limit = 10 } = req.query;
    const userId = req.user?.uid;

    const cacheKey = `replies:${commentId}:${page}:${limit}`;
    const cachedReplies = await cacheService.get(cacheKey);
    
    if (cachedReplies) {
      return res.json({
        success: true,
        data: cachedReplies,
        cached: true
      });
    }

    // Validate comment exists
    if (!commentId) {
      throw new ValidationError('Comment ID is required');
    }    const commentDoc = await this.firestore.collection('comments').doc(commentId).get();
    if (!commentDoc.exists) {
      throw new NotFoundError('Comment not found');
    }

    const pageNum = Number(page);
    const limitNum = Number(limit);
    const offset = (pageNum - 1) * limitNum;

    const repliesSnapshot = await this.firestore
      .collection('comments')
      .where('parentId', '==', commentId)
      .orderBy('createdAt', 'asc')
      .offset(offset)
      .limit(limitNum)
      .get();

    const replies = await Promise.all(
      repliesSnapshot.docs.map(async (doc: any) => {
        const replyData = doc.data();
        let userData = null;
        let isLiked = false;

        // Get user data
        try {
          const userDoc = await this.firestore.collection('users').doc(replyData['userId']).get();
          userData = userDoc.data();
        } catch (error) {
          logger.warn(`Failed to get user data for reply ${doc.id}`, error);
        }

        // Check if current user liked this reply
        if (userId) {
          const likeDoc = await this.firestore
            .collection('comment_likes')
            .doc(`${doc.id}_${userId}`)
            .get();
          isLiked = likeDoc.exists;
        }

        return {
          id: doc.id,
          content: replyData['content'],
          likeCount: replyData['likeCount'] || 0,
          createdAt: replyData['createdAt'],
          updatedAt: replyData['updatedAt'],
          isLiked,
          user: {
            uid: userData?.['uid'] || replyData['userId'],
            displayName: userData?.['displayName'] || 'Unknown User',
            username: userData?.['username'],
            profilePicture: userData?.['profilePicture'],
          },
        };
      })
    );

    const result = {
      replies,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total: repliesSnapshot.size,
        hasMore: repliesSnapshot.size === limitNum
      }
    };

    // Cache the result
    await cacheService.set(cacheKey, result, 300); // 5 minutes

    return res.json({
      success: true,
      data: result
    });
  });

  // Create a comment
  public createComment = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
    const { videoId } = req.params;
    const { content, parentId } = req.body;
    const userId = req.user?.uid;

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
      });
    }

    // Validate video exists
    if (!videoId) {
      throw new ValidationError('Video ID is required');
    }    const videoDoc = await this.firestore.collection('videos').doc(videoId).get();
    if (!videoDoc.exists) {
      throw new NotFoundError('Video not found');
    }

    // If this is a reply, check if parent comment exists
    if (parentId) {
      const parentDoc = await this.firestore.collection('comments').doc(parentId).get();
      if (!parentDoc.exists) {
        throw new NotFoundError('Parent comment not found');
      }

      // Check if parent is not already a reply (only 2 levels allowed)
      const parentData = parentDoc.data();
      if (parentData?.['parentId']) {
        throw new ValidationError('Cannot reply to a reply');
      }
    }

    const commentId = uuidv4();
    const commentData = {
      content,
      videoId,
      userId,
      parentId: parentId || null,
      likeCount: 0,
      createdAt: new Date(),
      updatedAt: new Date(),
    };    const batch = this.firestore.batch();

    // Create comment
    batch.set(this.firestore.collection('comments').doc(commentId), commentData);

    // Update video comment count (only for top-level comments)
    if (!parentId) {
      batch.update(this.firestore.collection('videos').doc(videoId), {
        commentCount: FieldValue.increment(1),
      });
    }

    await batch.commit();

    // Clear relevant caches
    await Promise.all([
      cacheService.del(`comments:${videoId}:date:desc:1:20`),
      cacheService.del(`video:${videoId}:${userId}`),
      parentId && cacheService.del(`replies:${parentId}:1:10`),
    ].filter(Boolean));

    // Get user info for response
    const userDoc = await this.firestore.collection('users').doc(userId).get();
    const userData = userDoc.data();

    const responseComment = {
      id: commentId,
      content,
      likeCount: 0,
      repliesCount: 0,
      createdAt: commentData.createdAt,
      updatedAt: commentData.updatedAt,
      isLiked: false,
      user: {
        uid: userId,
        displayName: userData?.['displayName'] || 'Unknown User',
        username: userData?.['username'],
        profilePicture: userData?.['profilePicture'],
      },
    };

    logger.info('Comment created', { commentId, videoId, userId, isReply: !!parentId });

    return res.status(201).json({
      success: true,
      data: responseComment,
    });
  });

  // Update a comment
  public updateComment = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
    const { commentId } = req.params;
    const { content } = req.body;
    const userId = req.user?.uid;

    if (!commentId) {
      throw new ValidationError('Comment ID is required');
    }    const commentDoc = await this.firestore.collection('comments').doc(commentId).get();

    if (!commentDoc.exists) {
      throw new NotFoundError('Comment not found');
    }

    const commentData = commentDoc.data();
    
    // Check ownership
    if (commentData?.['userId'] !== userId) {
      throw new ForbiddenError('You can only update your own comments');
    }

    // Check if comment is not too old (e.g., 24 hours)
    const createdAt = commentData?.['createdAt']?.toDate();
    const hoursSinceCreation = (Date.now() - createdAt.getTime()) / (1000 * 60 * 60);
    
    if (hoursSinceCreation > 24) {
      throw new ForbiddenError('Comments can only be edited within 24 hours');
    }

    await this.firestore.collection('comments').doc(commentId).update({
      content,
      updatedAt: new Date(),
    });

    // Clear relevant caches
    const videoId = commentData?.['videoId'];
    await Promise.all([
      cacheService.del(`comments:${videoId}:date:desc:1:20`),
      commentData?.['parentId'] && cacheService.del(`replies:${commentData['parentId']}:1:10`),
    ].filter(Boolean));

    logger.info('Comment updated', { commentId, userId });

    return res.json({
      success: true,
      message: 'Comment updated successfully',
    });
  });

  // Delete a comment
  public deleteComment = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
    const { commentId } = req.params;
    const userId = req.user?.uid;

    if (!commentId) {
      throw new ValidationError('Comment ID is required');
    }    const commentDoc = await this.firestore.collection('comments').doc(commentId).get();

    if (!commentDoc.exists) {
      throw new NotFoundError('Comment not found');
    }

    const commentData = commentDoc.data();
    
    // Check ownership or admin role
    if (commentData?.['userId'] !== userId && !req.user?.['roles']?.includes('admin')) {
      throw new ForbiddenError('You can only delete your own comments');
    }

    const batch = this.firestore.batch();

    // Delete comment
    batch.delete(this.firestore.collection('comments').doc(commentId));

    // Delete all replies if this is a parent comment
    if (!commentData?.['parentId']) {
      const repliesSnapshot = await this.firestore
        .collection('comments')
        .where('parentId', '==', commentId)
        .get();
      
      repliesSnapshot.docs.forEach((doc: any) => batch.delete(doc.ref));

      // Update video comment count
      batch.update(this.firestore.collection('videos').doc(commentData?.['videoId']), {
        commentCount: FieldValue.increment(-(1 + repliesSnapshot.size)),
      });
    }    // Delete comment likes
    const likesSnapshot = await this.firestore
      .collection('comment_likes')
      .where('commentId', '==', commentId)
      .get();
    
    likesSnapshot.docs.forEach((doc: any) => batch.delete(doc.ref));

    await batch.commit();

    // Clear relevant caches
    const videoId = commentData?.['videoId'];
    await Promise.all([
      cacheService.del(`comments:${videoId}:date:desc:1:20`),
      cacheService.del(`video:${videoId}:${userId}`),
      commentData?.['parentId'] && cacheService.del(`replies:${commentData['parentId']}:1:10`),
    ].filter(Boolean));

    logger.info('Comment deleted', { commentId, userId });

    return res.json({
      success: true,
      message: 'Comment deleted successfully',
    });
  });

  // Like/Unlike a comment
  public toggleLike = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
    const { commentId } = req.params;
    const userId = req.user?.uid;

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
      });
    }

    if (!commentId) {
      throw new ValidationError('Comment ID is required');
    }    // Check if comment exists
    const commentDoc = await this.firestore.collection('comments').doc(commentId).get();
    if (!commentDoc.exists) {
      throw new NotFoundError('Comment not found');
    }

    const likeDocId = `${userId}_${commentId}`;
    const likeDoc = await this.firestore.collection('comment_likes').doc(likeDocId).get();

    const batch = this.firestore.batch();
    let isLiked: boolean;

    if (likeDoc.exists) {
      // Unlike
      batch.delete(this.firestore.collection('comment_likes').doc(likeDocId));
      batch.update(this.firestore.collection('comments').doc(commentId), {
        likeCount: FieldValue.increment(-1),
      });
      isLiked = false;
    } else {
      // Like
      batch.set(this.firestore.collection('comment_likes').doc(likeDocId), {
        userId,
        commentId,
        createdAt: new Date(),
      });
      batch.update(this.firestore.collection('comments').doc(commentId), {
        likeCount: FieldValue.increment(1),
      });
      isLiked = true;
    }

    await batch.commit();

    // Clear relevant caches
    const commentData = commentDoc.data();
    const videoId = commentData?.['videoId'];
    await Promise.all([
      cacheService.del(`comments:${videoId}:date:desc:1:20`),
      commentData?.['parentId'] && cacheService.del(`replies:${commentData['parentId']}:1:10`),
    ].filter(Boolean));

    logger.info('Comment like toggled', { commentId, userId, isLiked });

    return res.json({
      success: true,
      data: {
        isLiked,
        message: isLiked ? 'Comment liked' : 'Comment unliked',
      },
    });
  });
}
