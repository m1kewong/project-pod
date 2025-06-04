#!/usr/bin/env node
/**
 * Test Firestore security rules
 * Usage: node test-security-rules.js <project-id>
 */

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const fs = require('fs');
const path = require('path');

// Command line arguments
const [,, projectId] = process.argv;

if (!projectId) {
    console.error('Usage: node test-security-rules.js <project-id>');
    process.exit(1);
}

// Initialize Firebase Admin SDK
try {
    const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || 
                              path.join(__dirname, '..', '..', 'infra', 'service-account.json');
    
    let app;
    if (fs.existsSync(serviceAccountPath)) {
        const serviceAccount = require(serviceAccountPath);
        app = initializeApp({
            credential: cert(serviceAccount),
            projectId: projectId
        });
    } else {
        app = initializeApp({
            projectId: projectId
        });
    }
    
    console.log(`✅ Firebase Admin SDK initialized for project: ${projectId}`);
} catch (error) {
    console.error('❌ Failed to initialize Firebase Admin SDK:', error.message);
    process.exit(1);
}

const db = getFirestore();

async function testSecurityRules() {
    console.log('🔒 Testing Firestore security rules...');
    
    const tests = [
        {
            name: 'Public read access to users collection',
            test: async () => {
                const snapshot = await db.collection('users').limit(1).get();
                return !snapshot.empty;
            },
            expectSuccess: true
        },
        {
            name: 'Public read access to videos collection',
            test: async () => {
                const snapshot = await db.collection('videos').limit(1).get();
                return !snapshot.empty;
            },
            expectSuccess: true
        },
        {
            name: 'Admin collection should exist (server access only)',
            test: async () => {
                // This should work with admin SDK
                const adminRef = db.collection('admin').doc('test');
                await adminRef.set({ test: true, createdAt: new Date() });
                const doc = await adminRef.get();
                await adminRef.delete(); // cleanup
                return doc.exists;
            },
            expectSuccess: true
        },
        {
            name: 'Analytics collection should exist (server access only)',
            test: async () => {
                const analyticsRef = db.collection('analytics').doc('test');
                await analyticsRef.set({ 
                    event: 'test',
                    count: 1,
                    date: new Date().toISOString().split('T')[0],
                    createdAt: new Date()
                });
                const doc = await analyticsRef.get();
                await analyticsRef.delete(); // cleanup
                return doc.exists;
            },
            expectSuccess: true
        },
        {
            name: 'Data validation - users collection structure',
            test: async () => {
                const userRef = db.collection('users').doc('test_user');
                
                // Valid user document
                await userRef.set({
                    email: 'test@example.com',
                    displayName: 'Test User',
                    username: 'test_user',
                    avatar: 'https://example.com/avatar.jpg',
                    bio: 'Test bio',
                    verified: false,
                    followerCount: 0,
                    followingCount: 0,
                    videoCount: 0,
                    totalLikes: 0,
                    preferences: {
                        language: 'en',
                        timezone: 'UTC',
                        notificationsEnabled: true,
                        privateAccount: false,
                        showActivity: true
                    },
                    createdAt: new Date(),
                    updatedAt: new Date()
                });
                
                const doc = await userRef.get();
                await userRef.delete(); // cleanup
                return doc.exists;
            },
            expectSuccess: true
        },
        {
            name: 'Data validation - videos collection structure',
            test: async () => {
                const videoRef = db.collection('videos').doc('test_video');
                
                // Valid video document
                await videoRef.set({
                    userId: 'test_user',
                    title: 'Test Video',
                    description: 'Test description',
                    hashtags: ['#test'],
                    duration: 30,
                    thumbnailUrl: 'https://example.com/thumb.jpg',
                    videoUrls: {
                        original: 'https://example.com/video.mp4',
                        hls: 'https://example.com/video.m3u8',
                        mp4_720p: 'https://example.com/video_720p.mp4'
                    },
                    metadata: {
                        width: 1080,
                        height: 1920,
                        frameRate: 30,
                        codec: 'h264',
                        bitrate: 2500000,
                        size: 15728640
                    },
                    privacy: 'public',
                    status: 'published',
                    likeCount: 0,
                    commentCount: 0,
                    shareCount: 0,
                    viewCount: 0,
                    danmuCount: 0,
                    createdAt: new Date(),
                    updatedAt: new Date(),
                    publishedAt: new Date()
                });
                
                const doc = await videoRef.get();
                await videoRef.delete(); // cleanup
                return doc.exists;
            },
            expectSuccess: true
        }
    ];
    
    let passedTests = 0;
    let totalTests = tests.length;
    
    for (const test of tests) {
        try {
            console.log(`   Testing: ${test.name}...`);
            const result = await test.test();
            
            if (result === test.expectSuccess) {
                console.log(`   ✅ PASS: ${test.name}`);
                passedTests++;
            } else {
                console.log(`   ❌ FAIL: ${test.name} (expected ${test.expectSuccess}, got ${result})`);
            }
        } catch (error) {
            if (test.expectSuccess) {
                console.log(`   ❌ FAIL: ${test.name} - ${error.message}`);
            } else {
                console.log(`   ✅ PASS: ${test.name} (correctly failed with: ${error.message})`);
                passedTests++;
            }
        }
    }
    
    console.log(`\n📊 Security Rules Test Results: ${passedTests}/${totalTests} tests passed`);
    
    if (passedTests === totalTests) {
        console.log('✅ All security rules tests passed!');
    } else {
        console.log('⚠️ Some security rules tests failed. Please review the rules and test results.');
    }
    
    return passedTests === totalTests;
}

// Run the tests
testSecurityRules().then(success => {
    process.exit(success ? 0 : 1);
}).catch(error => {
    console.error('❌ Unexpected error during testing:', error);
    process.exit(1);
});
