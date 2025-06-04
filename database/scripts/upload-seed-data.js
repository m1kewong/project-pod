#!/usr/bin/env node
/**
 * Upload seed data to Firestore
 * Usage: node upload-seed-data.js <collection> <json-file> <project-id>
 */

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const fs = require('fs');
const path = require('path');

// Command line arguments
const [,, collectionName, jsonFile, projectId] = process.argv;

if (!collectionName || !jsonFile || !projectId) {
    console.error('Usage: node upload-seed-data.js <collection> <json-file> <project-id>');
    process.exit(1);
}

// Initialize Firebase Admin SDK
try {
    // Try to use service account key if available
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
        // Use Application Default Credentials
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

async function uploadSeedData() {
    try {
        // Read the JSON file
        if (!fs.existsSync(jsonFile)) {
            throw new Error(`JSON file not found: ${jsonFile}`);
        }
        
        const rawData = fs.readFileSync(jsonFile, 'utf8');
        const documents = JSON.parse(rawData);
        
        if (!Array.isArray(documents)) {
            throw new Error('JSON file must contain an array of documents');
        }
        
        console.log(`📊 Uploading ${documents.length} documents to collection '${collectionName}'...`);
        
        // Create a batch for atomic operations
        const batch = db.batch();
        let batchCount = 0;
        const BATCH_SIZE = 500; // Firestore batch limit
        
        for (let i = 0; i < documents.length; i++) {
            const doc = documents[i];
            
            if (!doc.id) {
                console.warn(`⚠️ Document at index ${i} missing 'id' field, skipping...`);
                continue;
            }
            
            // Convert date strings to Firestore Timestamps
            const processedDoc = convertDates(doc);
            
            // Remove the id field from the document data
            const { id, ...docData } = processedDoc;
            
            const docRef = db.collection(collectionName).doc(id);
            batch.set(docRef, docData);
            batchCount++;
            
            // Commit batch when it reaches the limit
            if (batchCount >= BATCH_SIZE) {
                await batch.commit();
                console.log(`📝 Committed batch of ${batchCount} documents`);
                batchCount = 0;
            }
        }
        
        // Commit any remaining documents
        if (batchCount > 0) {
            await batch.commit();
            console.log(`📝 Committed final batch of ${batchCount} documents`);
        }
        
        console.log(`✅ Successfully uploaded ${documents.length} documents to '${collectionName}'`);
        
        // Verify the upload
        const snapshot = await db.collection(collectionName).limit(1).get();
        if (!snapshot.empty) {
            console.log(`✅ Verification: Collection '${collectionName}' contains data`);
        } else {
            console.warn(`⚠️ Verification: Collection '${collectionName}' appears to be empty`);
        }
        
    } catch (error) {
        console.error(`❌ Error uploading seed data:`, error.message);
        process.exit(1);
    }
}

/**
 * Convert date strings to Firestore Timestamps
 */
function convertDates(obj) {
    if (obj === null || typeof obj !== 'object') {
        return obj;
    }
    
    if (Array.isArray(obj)) {
        return obj.map(convertDates);
    }
    
    const result = {};
    for (const [key, value] of Object.entries(obj)) {
        if (typeof value === 'string' && isDateString(value)) {
            // Convert ISO date strings to Date objects (Firestore will handle Timestamp conversion)
            result[key] = new Date(value);
        } else if (typeof value === 'object' && value !== null) {
            result[key] = convertDates(value);
        } else {
            result[key] = value;
        }
    }
    return result;
}

/**
 * Check if a string is a valid ISO date string
 */
function isDateString(str) {
    // Check for ISO 8601 format: YYYY-MM-DDTHH:mm:ss.sssZ or YYYY-MM-DDTHH:mm:ssZ
    const isoDateRegex = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?Z?$/;
    return isoDateRegex.test(str) && !isNaN(Date.parse(str));
}

// Run the upload
uploadSeedData().catch(error => {
    console.error('❌ Unexpected error:', error);
    process.exit(1);
});
