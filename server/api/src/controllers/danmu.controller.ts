import { Response } from 'express';
import { AuthenticatedRequest } from '../middleware/auth.middleware';
import { firebaseService } from '../services/firebase.service';
import { cacheService } from '../services/cache.service';
import { NotFoundError, ForbiddenError, ValidationError } from '../utils/errors';
import { asyncHandler } from '../middleware/error.middleware';
import { v4 as uuidv4 } from 'uuid';

export class DanmuController {
  // Get danmu for a video
  public getDanmu = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
    const { videoId } = req.params;
    const { timestamp, duration = 10 } = req.query;

    const cacheKey = timestamp 
      ? `danmu:${videoId}:${timestamp}:${duration}`
      : `danmu:${videoId}:all`;
    
    const cachedDanmu = await cacheService.get(cacheKey);
    if (cachedDanmu) {
      return res.json({
        success: true,
        data: cachedDanmu,
      });
    }

    const firestore = firebaseService.getFirestore();
    
    const videoDoc = await firestore.collection('videos').doc(videoId as string).get();
    if (!videoDoc.exists) {
      throw new NotFoundError('Video');
    }

    let query = firestore
      .collection('danmu')
      .where('videoId', '==', videoId);

    if (timestamp) {
      const startTime = Number(timestamp) - Number(duration) / 2;
      const endTime = Number(timestamp) + Number(duration) / 2;
      
      query = query
        .where('timestamp', '>=', Math.max(0, startTime))
        .where('timestamp', '<=', endTime)
        .orderBy('timestamp', 'asc');
    } else {
      query = query.orderBy('timestamp', 'asc');
    }

    const danmuSnapshot = await query.get();

    const danmuList = await Promise.all(
      danmuSnapshot.docs.map(async (doc) => {
        const danmuData = doc.data();
        
        const userCacheKey = `user:basic:${danmuData['userId']}`;
        let userData = await cacheService.get(userCacheKey);
        
        if (!userData) {
          const userDoc = await firestore.collection('users').doc(danmuData['userId']).get();
          userData = userDoc.exists ? {
            uid: userDoc.id,
            displayName: userDoc.data()?.['displayName'] || 'Anonymous',
            username: userDoc.data()?.['username'],
          } : {
            uid: danmuData['userId'],
            displayName: 'Anonymous',
            username: null,
          };
          
          await cacheService.set(userCacheKey, userData, 600);
        }

        return {
          id: doc.id,
          content: danmuData['content'],
          timestamp: danmuData['timestamp'],
          color: danmuData['color'] || '#FFFFFF',
          size: danmuData['size'] || 'medium',
          position: danmuData['position'] || 'scroll',
          speed: danmuData['speed'] || 1,
          createdAt: danmuData['createdAt'],
          user: userData,
        };
      })
    );

    const result = {
      danmu: danmuList,
      total: danmuList.length,
      videoId,
      ...(timestamp && {
        timestamp: Number(timestamp),
        duration: Number(duration),
      }),
    };

    await cacheService.set(cacheKey, result, 30);

    return res.json({
      success: true,
      data: result,
    });
  });

  // Create danmu
  public createDanmu = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
    const { videoId } = req.params;
    const { 
      content, 
      timestamp, 
      color = '#FFFFFF', 
      size = 'medium', 
      position = 'scroll',
      speed = 1 
    } = req.body;
    const userId = req.user?.uid;

    const firestore = firebaseService.getFirestore();
    
    const videoDoc = await firestore.collection('videos').doc(videoId as string).get();
    if (!videoDoc.exists) {
      throw new NotFoundError('Video');
    }

    const videoData = videoDoc.data();
    
    if (timestamp > (videoData?.['duration'] || 0)) {
      throw new ValidationError('Timestamp exceeds video duration');
    }

    const danmuId = uuidv4();
    const danmuData = {
      content: content.trim(),
      timestamp: Number(timestamp),
      color,
      size,
      position,
      speed: Number(speed),
      videoId: videoId as string,
      userId: userId as string,
      status: 'active',
      createdAt: new Date(),
    };

    await firestore.collection('danmu').doc(danmuId).set(danmuData);

    const userDoc = await firestore.collection('users').doc(userId as string).get();
    const userData = userDoc.data();

    const responseDanmu = {
      id: danmuId,
      content: danmuData.content,
      timestamp: danmuData.timestamp,
      color: danmuData.color,
      size: danmuData.size,
      position: danmuData.position,
      speed: danmuData.speed,
      createdAt: danmuData.createdAt,
      user: {
        uid: userId,
        displayName: userData?.['displayName'] || 'Anonymous',
        username: userData?.['username'],
      },
    };

    await Promise.all([
      cacheService.del(`danmu:${videoId}:all`),
      cacheService.del(`danmu:${videoId}:${timestamp}:10`),
    ]);

    return res.status(201).json({
      success: true,
      data: responseDanmu,
    });
  });

  // Delete danmu
  public deleteDanmu = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
    const { danmuId } = req.params;
    const userId = req.user?.uid;

    const firestore = firebaseService.getFirestore();
    const danmuDoc = await firestore.collection('danmu').doc(danmuId as string).get();

    if (!danmuDoc.exists) {
      throw new NotFoundError('Danmu');
    }

    const danmuData = danmuDoc.data();
    
    if (danmuData?.['userId'] !== userId && !req.user?.roles?.includes('admin')) {
      throw new ForbiddenError('You can only delete your own danmu');
    }

    await firestore.collection('danmu').doc(danmuId as string).update({
      status: 'deleted',
      deletedAt: new Date(),
      deletedBy: userId,
    });

    const videoId = danmuData?.['videoId'];
    const timestamp = danmuData?.['timestamp'];
    
    await Promise.all([
      cacheService.del(`danmu:${videoId}:all`),
      cacheService.del(`danmu:${videoId}:${timestamp}:10`),
    ]);

    return res.json({
      success: true,
      message: 'Danmu deleted successfully',
    });
  });

  // Hide danmu
  public hideDanmu = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
    const { danmuId } = req.params;
    const { reason } = req.body;
    const userId = req.user?.uid;

    if (!req.user?.roles?.includes('moderator') && !req.user?.roles?.includes('admin')) {
      throw new ForbiddenError('Moderator permissions required');
    }

    const firestore = firebaseService.getFirestore();
    const danmuDoc = await firestore.collection('danmu').doc(danmuId as string).get();

    if (!danmuDoc.exists) {
      throw new NotFoundError('Danmu');
    }

    const danmuData = danmuDoc.data();

    await firestore.collection('danmu').doc(danmuId as string).update({
      status: 'hidden',
      hiddenAt: new Date(),
      hiddenBy: userId,
      hiddenReason: reason || 'Content violation',
    });

    const videoId = danmuData?.['videoId'];
    const timestamp = danmuData?.['timestamp'];
    
    await Promise.all([
      cacheService.del(`danmu:${videoId}:all`),
      cacheService.del(`danmu:${videoId}:${timestamp}:10`),
    ]);

    return res.json({
      success: true,
      message: 'Danmu hidden successfully',
    });
  });

  // Get danmu statistics
  public getDanmuStats = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
    const { videoId } = req.params;

    const cacheKey = `danmu:stats:${videoId}`;
    const cachedStats = await cacheService.get(cacheKey);
    
    if (cachedStats) {
      return res.json({
        success: true,
        data: cachedStats,
      });
    }

    const firestore = firebaseService.getFirestore();
    
    const videoDoc = await firestore.collection('videos').doc(videoId as string).get();
    if (!videoDoc.exists) {
      throw new NotFoundError('Video');
    }

    const videoData = videoDoc.data();
    const videoDuration = videoData?.['duration'] || 0;

    const danmuSnapshot = await firestore
      .collection('danmu')
      .where('videoId', '==', videoId)
      .where('status', '==', 'active')
      .get();

    const totalDanmu = danmuSnapshot.size;
    const uniqueUsers = new Set(danmuSnapshot.docs.map(doc => doc.data()['userId'])).size;
    
    const densityMap: { [minute: number]: number } = {};
    const maxMinute = Math.ceil(videoDuration / 60);
    
    for (let i = 0; i < maxMinute; i++) {
      densityMap[i] = 0;
    }

    danmuSnapshot.docs.forEach(doc => {
      const timestamp = doc.data()['timestamp'];
      const minute = Math.floor(timestamp / 60);
      if (densityMap[minute] !== undefined) {
        densityMap[minute]++;
      }
    });

    const peakMoments = Object.entries(densityMap)
      .map(([minute, count]) => ({ minute: Number(minute), count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 5);

    const colorStats: { [color: string]: number } = {};
    danmuSnapshot.docs.forEach(doc => {
      const color = doc.data()['color'] || '#FFFFFF';
      colorStats[color] = (colorStats[color] || 0) + 1;
    });

    const stats = {
      videoId,
      totalDanmu,
      uniqueUsers,
      averageDanmuPerMinute: videoDuration > 0 ? totalDanmu / (videoDuration / 60) : 0,
      densityMap,
      peakMoments,
      colorDistribution: colorStats,
      lastUpdated: new Date(),
    };

    await cacheService.set(cacheKey, stats, 300);

    return res.json({
      success: true,
      data: stats,
    });
  });
}
