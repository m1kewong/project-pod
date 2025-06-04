import { Response } from 'express';
import { AuthenticatedRequest } from '../middleware/auth.middleware';
import { firebaseService, FieldValue, FieldPath } from '../services/firebase.service';
import { cacheService } from '../services/cache.service';
import { logger } from '../utils/logger';
import { NotFoundError, ValidationError } from '../utils/errors';
import { asyncHandler } from '../middleware/error.middleware';

export class UserController {
  // Get user profile
  public getProfile = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
    const { userId } = req.params;
    const requestingUserId = req.user?.uid;

    if (!userId) {
      throw new ValidationError('User ID is required');
    }

    // Check cache first
    const cacheKey = `user:profile:${userId}`;
    const cachedProfile = await cacheService.get(cacheKey);
    
    if (cachedProfile) {
      logger.debug('User profile served from cache', { userId });
      return res.json({
        success: true,
        data: cachedProfile,
      });
    }

    const firestore = firebaseService.getFirestore();
    const userDoc = await firestore.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      throw new NotFoundError('User');
    }

    const userData = userDoc.data();
    
    // Filter sensitive information for non-owners
    const profile = {
      uid: userDoc.id,
      displayName: userData?.['displayName'],
      username: userData?.['username'],
      bio: userData?.['bio'],
      profilePicture: userData?.['profilePicture'],
      followersCount: userData?.['followersCount'] || 0,
      followingCount: userData?.['followingCount'] || 0,
      videosCount: userData?.['videosCount'] || 0,
      createdAt: userData?.['createdAt'],
      isFollowing: false,
      // Only show email and other sensitive data to the user themselves
      ...(requestingUserId === userId && {
        email: userData?.['email'],
        emailVerified: userData?.['emailVerified'],
        lastLoginAt: userData?.['lastLoginAt'],
      }),
    };

    // Check if requesting user follows this user
    if (requestingUserId && requestingUserId !== userId) {
      const followDoc = await firestore
        .collection('follows')
        .doc(`${requestingUserId}_${userId}`)
        .get();
      profile.isFollowing = followDoc.exists;
    }

    // Cache the result
    await cacheService.set(cacheKey, profile, 300); // 5 minutes

    logger.info('User profile retrieved', { userId, requestingUserId });

    return res.json({
      success: true,
      data: profile,
    });
  });

  // Update user profile
  public updateProfile = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
    const { userId } = req.params;
    const requestingUserId = req.user?.uid;

    if (!userId) {
      throw new ValidationError('User ID is required');
    }

    // Users can only update their own profile
    if (requestingUserId !== userId) {
      return res.status(403).json({
        success: false,
        error: 'You can only update your own profile',
        code: 'FORBIDDEN',
      });
    }

    const { displayName, bio, profilePicture } = req.body;
    const firestore = firebaseService.getFirestore();

    // Check if user exists
    const userDoc = await firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw new NotFoundError('User');
    }

    // Update user document
    const updateData: any = {
      updatedAt: new Date(),
    };

    if (displayName !== undefined) updateData.displayName = displayName;
    if (bio !== undefined) updateData.bio = bio;
    if (profilePicture !== undefined) updateData.profilePicture = profilePicture;

    await firestore.collection('users').doc(userId).update(updateData);

    // Clear cache
    await cacheService.del(`user:profile:${userId}`);

    logger.info('User profile updated', { userId, fields: Object.keys(updateData) });

    return res.json({
      success: true,
      message: 'Profile updated successfully',
    });
  });

  // Get user's videos
  public getUserVideos = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
    const { userId } = req.params;
    const { page = 1, limit = 20 } = req.query;
    const requestingUserId = req.user?.uid;

    if (!userId) {
      throw new ValidationError('User ID is required');
    }

    const firestore = firebaseService.getFirestore();
    
    // Check cache
    const cacheKey = `user:videos:${userId}:${page}:${limit}`;
    const cachedVideos = await cacheService.get(cacheKey);
    
    if (cachedVideos) {
      return res.json({
        success: true,
        data: cachedVideos,
      });
    }

    let query = firestore
      .collection('videos')
      .where('userId', '==', userId)
      .orderBy('createdAt', 'desc');

    // If not the user themselves, only show public videos
    if (requestingUserId !== userId) {
      query = query.where('visibility', '==', 'public');
    }

    const offset = (Number(page) - 1) * Number(limit);
    const videosSnapshot = await query.offset(offset).limit(Number(limit)).get();

    const videos = videosSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));

    const result = {
      videos,
      pagination: {
        page: Number(page),
        limit: Number(limit),
        total: videosSnapshot.size,
        hasMore: videosSnapshot.size === Number(limit),
      },
    };

    // Cache result
    await cacheService.set(cacheKey, result, 180); // 3 minutes

    return res.json({
      success: true,
      data: result,
    });
  });

  // Follow/Unfollow user
  public toggleFollow = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
    const { userId } = req.params;
    const followerId = req.user?.uid;

    if (!userId) {
      throw new ValidationError('User ID is required');
    }

    if (!followerId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
      });
    }

    if (followerId === userId) {
      throw new ValidationError('You cannot follow yourself');
    }

    const firestore = firebaseService.getFirestore();
    const followDocId = `${followerId}_${userId}`;
    const followDoc = await firestore.collection('follows').doc(followDocId).get();

    const batch = firestore.batch();
    let isFollowing: boolean;

    if (followDoc.exists) {
      // Unfollow
      batch.delete(firestore.collection('follows').doc(followDocId));
      batch.update(firestore.collection('users').doc(userId), {
        followersCount: FieldValue.increment(-1),
      });
      batch.update(firestore.collection('users').doc(followerId), {
        followingCount: FieldValue.increment(-1),
      });
      isFollowing = false;
    } else {
      // Follow
      batch.set(firestore.collection('follows').doc(followDocId), {
        followerId,
        followingId: userId,
        createdAt: new Date(),
      });
      batch.update(firestore.collection('users').doc(userId), {
        followersCount: FieldValue.increment(1),
      });
      batch.update(firestore.collection('users').doc(followerId), {
        followingCount: FieldValue.increment(1),
      });
      isFollowing = true;
    }

    await batch.commit();

    // Clear relevant caches
    await Promise.all([
      cacheService.del(`user:profile:${userId}`),
      cacheService.del(`user:profile:${followerId}`),
    ]);

    logger.info('Follow status updated', { followerId, userId, isFollowing });

    return res.json({
      success: true,
      data: {
        isFollowing,
        message: isFollowing ? 'User followed successfully' : 'User unfollowed successfully',
      },
    });
  });

  // Get user's followers
  public getFollowers = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
    const { userId } = req.params;
    const { page = 1, limit = 20 } = req.query;

    if (!userId) {
      throw new ValidationError('User ID is required');
    }

    const firestore = firebaseService.getFirestore();
    
    const cacheKey = `user:followers:${userId}:${page}:${limit}`;
    const cachedFollowers = await cacheService.get(cacheKey);
    
    if (cachedFollowers) {
      return res.json({
        success: true,
        data: cachedFollowers,
      });
    }

    const offset = (Number(page) - 1) * Number(limit);
    const followsSnapshot = await firestore
      .collection('follows')
      .where('followingId', '==', userId)
      .orderBy('createdAt', 'desc')
      .offset(offset)
      .limit(Number(limit))
      .get();

    const followerIds = followsSnapshot.docs.map(doc => doc.data()['followerId']);
    
    // Get follower details
    const followers = [];
    if (followerIds.length > 0) {
      const usersSnapshot = await firestore
        .collection('users')
        .where(FieldPath.documentId(), 'in', followerIds)
        .get();

      for (const userDoc of usersSnapshot.docs) {
        const userData = userDoc.data();
        followers.push({
          uid: userDoc.id,
          displayName: userData['displayName'],
          username: userData['username'],
          profilePicture: userData['profilePicture'],
        });
      }
    }

    const result = {
      followers,
      pagination: {
        page: Number(page),
        limit: Number(limit),
        total: followsSnapshot.size,
        hasMore: followsSnapshot.size === Number(limit),
      },
    };

    await cacheService.set(cacheKey, result, 300); // 5 minutes

    return res.json({
      success: true,
      data: result,
    });
  });

  // Get user's following
  public getFollowing = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
    const { userId } = req.params;
    const { page = 1, limit = 20 } = req.query;

    if (!userId) {
      throw new ValidationError('User ID is required');
    }

    const firestore = firebaseService.getFirestore();
    
    const cacheKey = `user:following:${userId}:${page}:${limit}`;
    const cachedFollowing = await cacheService.get(cacheKey);
    
    if (cachedFollowing) {
      return res.json({
        success: true,
        data: cachedFollowing,
      });
    }

    const offset = (Number(page) - 1) * Number(limit);
    const followsSnapshot = await firestore
      .collection('follows')
      .where('followerId', '==', userId)
      .orderBy('createdAt', 'desc')
      .offset(offset)
      .limit(Number(limit))
      .get();

    const followingIds = followsSnapshot.docs.map(doc => doc.data()['followingId']);
    
    // Get following user details
    const following = [];
    if (followingIds.length > 0) {
      const usersSnapshot = await firestore
        .collection('users')
        .where(FieldPath.documentId(), 'in', followingIds)
        .get();

      for (const userDoc of usersSnapshot.docs) {
        const userData = userDoc.data();
        following.push({
          uid: userDoc.id,
          displayName: userData['displayName'],
          username: userData['username'],
          profilePicture: userData['profilePicture'],
        });
      }
    }

    const result = {
      following,
      pagination: {
        page: Number(page),
        limit: Number(limit),
        total: followsSnapshot.size,
        hasMore: followsSnapshot.size === Number(limit),
      },
    };

    await cacheService.set(cacheKey, result, 300); // 5 minutes

    return res.json({
      success: true,
      data: result,
    });
  });
}
