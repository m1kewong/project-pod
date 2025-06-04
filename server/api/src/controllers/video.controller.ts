import { Response } from 'express';
import { AuthenticatedRequest } from '../middleware/auth.middleware';
import { firebaseService, FieldValue } from '../services/firebase.service';
import { cacheService } from '../services/cache.service';
import { logger } from '../utils/logger';
import { NotFoundError, ForbiddenError, ValidationError } from '../utils/errors';
import { asyncHandler } from '../middleware/error.middleware';
import { v4 as uuidv4 } from 'uuid';

export class VideoController {
  // Get video feed
  public getFeed = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
    const { page = 1, limit = 20, sort = 'date', order = 'desc' } = req.query;
    const userId = req.user?.uid;

    const cacheKey = `video:feed:${sort}:${order}:${page}:${limit}:${userId || 'anonymous'}`;
    const cachedFeed = await cacheService.get(cacheKey);
    
    if (cachedFeed) {
      logger.debug('Video feed served from cache');
      return res.json({
        success: true,
        data: cachedFeed,
      });
    }

    const firestore = firebaseService.getFirestore();
    let query = firestore
      .collection('videos')
      .where('visibility', '==', 'public')
      .where('status', '==', 'published');

    // Apply sorting
    switch (sort) {
      case 'popular':
        query = query.orderBy('likeCount', order as any);
        break;
      case 'views':
        query = query.orderBy('viewCount', order as any);
        break;
      default:
        query = query.orderBy('createdAt', order as any);
    }

    const offset = (Number(page) - 1) * Number(limit);
    const videosSnapshot = await query
      .offset(offset)
      .limit(Number(limit))
      .get();

    const videos = await Promise.all(
      videosSnapshot.docs.map(async (doc) => {
        const videoData = doc.data();
        
        // Get user info
        const userDoc = await firestore
          .collection('users')
          .doc(videoData['userId'])
          .get();
        
        const userData = userDoc.exists ? userDoc.data() : null;

        return {
          id: doc.id,
          title: videoData['title'],
          description: videoData['description'],
          thumbnailUrl: videoData['thumbnailUrl'],
          videoUrl: videoData['videoUrl'],
          duration: videoData['duration'],
          viewCount: videoData['viewCount'] || 0,
          likeCount: videoData['likeCount'] || 0,
          commentCount: videoData['commentCount'] || 0,
          tags: videoData['tags'] || [],
          createdAt: videoData['createdAt'],
          user: userData ? {
            uid: userDoc.id,
            displayName: userData['displayName'],
            username: userData['username'],
            profilePicture: userData['profilePicture'],
          } : null,
        };
      })
    );

    const result = {
      videos,
      pagination: {
        page: Number(page),
        limit: Number(limit),
        total: videosSnapshot.size,
        hasMore: videosSnapshot.size === Number(limit),
      },
    };

    // Cache the result
    await cacheService.set(cacheKey, result, 300); // 5 minutes

    logger.info('Video feed retrieved', { 
      page: Number(page), 
      limit: Number(limit), 
      videoCount: videos.length 
    });

    return res.json({
      success: true,
      data: result,
    });
  });

  // Get single video
  public getVideo = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
    const { videoId } = req.params;
    const userId = req.user?.uid;

    if (!videoId) {
      throw new ValidationError('Video ID is required');
    }

    const cacheKey = `video:${videoId}:${userId || 'anonymous'}`;
    const cachedVideo = await cacheService.get(cacheKey);
    
    if (cachedVideo) {
      return res.json({
        success: true,
        data: cachedVideo,
      });
    }

    const firestore = firebaseService.getFirestore();
    const videoDoc = await firestore.collection('videos').doc(videoId).get();

    if (!videoDoc.exists) {
      throw new NotFoundError('Video');
    }

    const videoData = videoDoc.data();

    // Check visibility permissions
    if (videoData?.['visibility'] === 'private' && videoData?.['userId'] !== userId) {
      throw new ForbiddenError('This video is private');
    }

    // Get user info
    const userDoc = await firestore
      .collection('users')
      .doc(videoData!['userId'])
      .get();
    
    const userData = userDoc.exists ? userDoc.data() : null;

    const video = {
      id: videoDoc.id,
      title: videoData?.['title'],
      description: videoData?.['description'],
      thumbnailUrl: videoData?.['thumbnailUrl'],
      videoUrl: videoData?.['videoUrl'],
      duration: videoData?.['duration'],
      viewCount: videoData?.['viewCount'] || 0,
      likeCount: videoData?.['likeCount'] || 0,
      commentCount: videoData?.['commentCount'] || 0,
      tags: videoData?.['tags'] || [],
      visibility: videoData?.['visibility'],
      status: videoData?.['status'],
      createdAt: videoData?.['createdAt'],
      updatedAt: videoData?.['updatedAt'],
      user: userData ? {
        uid: userDoc.id,
        displayName: userData['displayName'],
        username: userData['username'],
        profilePicture: userData['profilePicture'],
      } : null,
    };

    // Increment view count asynchronously (don't wait for it)
    this.incrementViewCount(videoId, userId).catch(error => {
      logger.error('Failed to increment view count', { videoId, userId, error });
    });

    // Cache the result
    await cacheService.set(cacheKey, video, 600); // 10 minutes

    logger.info('Video retrieved', { videoId, userId });

    return res.json({
      success: true,
      data: video,
    });
  });

  // Create new video
  public createVideo = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
    const userId = req.user?.uid;
    const {
      title,
      description,
      thumbnailUrl,
      videoUrl,
      duration,
      tags = [],
      visibility = 'public',
    } = req.body;

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
      });
    }

    if (!title || !videoUrl) {
      throw new ValidationError('Title and video URL are required');
    }

    const firestore = firebaseService.getFirestore();
    const videoId = uuidv4();

    const videoData = {
      title,
      description: description || '',
      thumbnailUrl: thumbnailUrl || '',
      videoUrl,
      duration: duration || 0,
      userId,
      tags: Array.isArray(tags) ? tags : [],
      visibility,
      status: 'published',
      viewCount: 0,
      likeCount: 0,
      commentCount: 0,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    const batch = firestore.batch();
    
    // Create video document
    batch.set(firestore.collection('videos').doc(videoId), videoData);
    
    // Update user's video count
    batch.update(firestore.collection('users').doc(userId), {
      videosCount: FieldValue.increment(1),
    });

    await batch.commit();

    // Clear relevant caches
    await Promise.all([
      cacheService.del(`user:profile:${userId}`),
      cacheService.del(`user:videos:${userId}:*`),
    ]);

    logger.info('Video created', { videoId, userId, title });

    return res.status(201).json({
      success: true,
      data: {
        id: videoId,
        message: 'Video created successfully',
      },
    });
  });

  // Update video
  public updateVideo = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
    const { videoId } = req.params;
    const userId = req.user?.uid;

    if (!videoId) {
      throw new ValidationError('Video ID is required');
    }

    const firestore = firebaseService.getFirestore();
    const videoDoc = await firestore.collection('videos').doc(videoId).get();

    if (!videoDoc.exists) {
      throw new NotFoundError('Video');
    }

    const videoData = videoDoc.data();

    // Check ownership
    if (videoData?.['userId'] !== userId) {
      throw new ForbiddenError('You can only edit your own videos');
    }

    const { title, description, thumbnailUrl, tags, visibility } = req.body;

    const updateData: any = {
      updatedAt: new Date(),
    };

    if (title !== undefined) updateData.title = title;
    if (description !== undefined) updateData.description = description;
    if (thumbnailUrl !== undefined) updateData.thumbnailUrl = thumbnailUrl;
    if (tags !== undefined) updateData.tags = Array.isArray(tags) ? tags : [];
    if (visibility !== undefined) updateData.visibility = visibility;

    await firestore.collection('videos').doc(videoId).update(updateData);

    // Clear caches
    await Promise.all([
      cacheService.del(`video:${videoId}:*`),
      cacheService.del(`user:videos:${userId}:*`),
    ]);

    logger.info('Video updated', { videoId, userId, fields: Object.keys(updateData) });

    return res.json({
      success: true,
      message: 'Video updated successfully',
    });
  });

  // Delete video
  public deleteVideo = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
    const { videoId } = req.params;
    const userId = req.user?.uid;

    if (!videoId) {
      throw new ValidationError('Video ID is required');
    }

    const firestore = firebaseService.getFirestore();
    const videoDoc = await firestore.collection('videos').doc(videoId).get();

    if (!videoDoc.exists) {
      throw new NotFoundError('Video');
    }

    const videoData = videoDoc.data();

    // Check ownership or admin rights
    if (videoData?.['userId'] !== userId && !req.user?.roles?.includes('admin')) {
      throw new ForbiddenError('You can only delete your own videos');
    }

    const batch = firestore.batch();

    // Delete video document
    batch.delete(firestore.collection('videos').doc(videoId));

    // Delete related comments
    const commentsSnapshot = await firestore
      .collection('comments')
      .where('videoId', '==', videoId)
      .get();

    commentsSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });

    // Delete related likes
    const likesSnapshot = await firestore
      .collection('likes')
      .where('videoId', '==', videoId)
      .get();

    likesSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });

    // Update user's video count
    batch.update(firestore.collection('users').doc(videoData?.['userId']), {
      videosCount: FieldValue.increment(-1),
    });

    await batch.commit();

    // Clear caches
    await Promise.all([
      cacheService.del(`video:${videoId}:*`),
      cacheService.del(`user:videos:${videoData?.['userId']}:*`),
      cacheService.del(`user:profile:${videoData?.['userId']}`),
    ]);

    logger.info('Video deleted', { videoId, userId });

    return res.json({
      success: true,
      message: 'Video deleted successfully',
    });
  });

  // Toggle like on video
  public toggleLike = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
    const { videoId } = req.params;
    const userId = req.user?.uid;

    if (!videoId) {
      throw new ValidationError('Video ID is required');
    }

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
      });
    }

    const firestore = firebaseService.getFirestore();
    const videoDoc = await firestore.collection('videos').doc(videoId).get();

    if (!videoDoc.exists) {
      throw new NotFoundError('Video');
    }

    const likeDocId = `${userId}_${videoId}`;
    const likeDoc = await firestore.collection('likes').doc(likeDocId).get();

    const batch = firestore.batch();
    let isLiked: boolean;

    if (likeDoc.exists) {
      // Unlike
      batch.delete(firestore.collection('likes').doc(likeDocId));
      batch.update(firestore.collection('videos').doc(videoId), {
        likeCount: FieldValue.increment(-1),
      });
      isLiked = false;
    } else {
      // Like
      batch.set(firestore.collection('likes').doc(likeDocId), {
        userId,
        videoId,
        createdAt: new Date(),
      });
      batch.update(firestore.collection('videos').doc(videoId), {
        likeCount: FieldValue.increment(1),
      });
      isLiked = true;
    }

    await batch.commit();

    // Clear video cache
    await cacheService.del(`video:${videoId}:*`);

    logger.info('Video like toggled', { videoId, userId, isLiked });

    return res.json({
      success: true,
      data: {
        isLiked,
        message: isLiked ? 'Video liked' : 'Video unliked',
      },
    });
  });

  // Search videos
  public searchVideos = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
    const { q: query, page = 1, limit = 20, tags, sort = 'relevance' } = req.query;

    if (!query || typeof query !== 'string') {
      throw new ValidationError('Search query is required');
    }

    const cacheKey = `video:search:${query}:${tags || ''}:${sort}:${page}:${limit}`;
    const cachedResults = await cacheService.get(cacheKey);
    
    if (cachedResults) {
      return res.json({
        success: true,
        data: cachedResults,
      });
    }

    const firestore = firebaseService.getFirestore();
    
    // Basic text search (would be better with Algolia or Elasticsearch in production)
    let searchQuery = firestore
      .collection('videos')
      .where('visibility', '==', 'public')
      .where('status', '==', 'published');

    // For now, we'll do a simple title search
    // In production, you'd want to use a proper search service
    const searchResults = await searchQuery.get();

    const queryLower = query.toLowerCase();
    let filteredVideos = searchResults.docs.filter(doc => {
      const data = doc.data();
      const title = data['title']?.toLowerCase() || '';
      const description = data['description']?.toLowerCase() || '';
      const videoTags = data['tags'] || [];
      
      // Check title and description
      const matchesText = title.includes(queryLower) || description.includes(queryLower);
      
      // Check tags if specified
      let matchesTags = true;
      if (tags && typeof tags === 'string') {
        const requestedTags = tags.split(',').map(tag => tag.trim().toLowerCase());
        matchesTags = requestedTags.some(tag => 
          videoTags.some((videoTag: string) => videoTag.toLowerCase().includes(tag))
        );
      }
      
      return matchesText && matchesTags;
    });

    // Apply sorting
    filteredVideos = filteredVideos.sort((a, b) => {
      const aData = a.data();
      const bData = b.data();
      
      switch (sort) {
        case 'date':
          return new Date(bData['createdAt']).getTime() - new Date(aData['createdAt']).getTime();
        case 'views':
          return (bData['viewCount'] || 0) - (aData['viewCount'] || 0);
        case 'likes':
          return (bData['likeCount'] || 0) - (aData['likeCount'] || 0);
        default: // relevance
          // Simple relevance scoring based on title match
          const aTitle = aData['title']?.toLowerCase() || '';
          const bTitle = bData['title']?.toLowerCase() || '';
          const aScore = aTitle.includes(queryLower) ? 2 : 1;
          const bScore = bTitle.includes(queryLower) ? 2 : 1;
          return bScore - aScore;
      }
    });

    // Apply pagination
    const offset = (Number(page) - 1) * Number(limit);
    const paginatedVideos = filteredVideos.slice(offset, offset + Number(limit));

    // Get video details with user info
    const videos = await Promise.all(
      paginatedVideos.map(async (doc) => {
        const videoData = doc.data();
        
        // Get user info
        const userDoc = await firestore
          .collection('users')
          .doc(videoData['userId'])
          .get();
        
        const userData = userDoc.exists ? userDoc.data() : null;

        return {
          id: doc.id,
          title: videoData['title'],
          description: videoData['description'],
          thumbnailUrl: videoData['thumbnailUrl'],
          videoUrl: videoData['videoUrl'],
          duration: videoData['duration'],
          viewCount: videoData['viewCount'] || 0,
          likeCount: videoData['likeCount'] || 0,
          commentCount: videoData['commentCount'] || 0,
          tags: videoData['tags'] || [],
          createdAt: videoData['createdAt'],
          user: userData ? {
            uid: userDoc.id,
            displayName: userData['displayName'],
            username: userData['username'],
            profilePicture: userData['profilePicture'],
          } : null,
        };
      })
    );

    const result = {
      videos,
      query,
      pagination: {
        page: Number(page),
        limit: Number(limit),
        total: filteredVideos.length,
        hasMore: offset + Number(limit) < filteredVideos.length,
      },
    };

    // Cache results
    await cacheService.set(cacheKey, result, 300); // 5 minutes

    logger.info('Video search performed', { 
      query, 
      resultsCount: videos.length,
      totalMatches: filteredVideos.length 
    });

    return res.json({
      success: true,
      data: result,
    });
  });

  // Private method to increment view count
  private async incrementViewCount(videoId: string, userId?: string): Promise<void> {
    try {
      const firestore = firebaseService.getFirestore();
      
      // Simple view tracking - in production you might want to implement
      // more sophisticated view counting with rate limiting
      await firestore.collection('videos').doc(videoId).update({
        viewCount: FieldValue.increment(1),
      });

      // Optionally track user views for analytics
      if (userId) {
        const viewDoc = firestore
          .collection('views')
          .doc(`${userId}_${videoId}`);
        
        await viewDoc.set({
          userId,
          videoId,
          viewedAt: new Date(),
        }, { merge: true });
      }

      // Clear cache
      await cacheService.del(`video:${videoId}:*`);
      
    } catch (error) {
      logger.error('Failed to increment view count', { videoId, userId, error });
    }
  }
}
