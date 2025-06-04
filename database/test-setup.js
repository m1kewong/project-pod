#!/usr/bin/env node
/**
 * Simple test script to verify Firestore setup
 * Usage: node test-setup.js [project-id]
 */

const projectId = process.argv[2] || 'project-pod-dev';

console.log('🧪 Testing Firestore Database Setup');
console.log(`Project ID: ${projectId}`);
console.log('');

// Test 1: Check if files exist
const fs = require('fs');
const path = require('path');

const requiredFiles = [
    'firestore.rules',
    'firestore.indexes.json',
    'schema.md',
    'package.json',
    'seed-data/users.json',
    'seed-data/videos.json',
    'seed-data/danmu_comments.json',
    'seed-data/notifications.json',
    'seed-data/follows.json',
    'seed-data/activities.json'
];

console.log('📁 Checking required files...');
let allFilesExist = true;

requiredFiles.forEach(file => {
    const filePath = path.join(__dirname, file);
    if (fs.existsSync(filePath)) {
        console.log(`✅ ${file}`);
    } else {
        console.log(`❌ ${file} - NOT FOUND`);
        allFilesExist = false;
    }
});

console.log('');

// Test 2: Validate JSON files
console.log('🔍 Validating JSON files...');
const jsonFiles = [
    'firestore.indexes.json',
    'package.json',
    'seed-data/users.json',
    'seed-data/videos.json',
    'seed-data/danmu_comments.json',
    'seed-data/notifications.json',
    'seed-data/follows.json',
    'seed-data/activities.json'
];

let allJsonValid = true;

jsonFiles.forEach(file => {
    const filePath = path.join(__dirname, file);
    if (fs.existsSync(filePath)) {
        try {
            const content = fs.readFileSync(filePath, 'utf8');
            JSON.parse(content);
            console.log(`✅ ${file} - Valid JSON`);
        } catch (error) {
            console.log(`❌ ${file} - Invalid JSON: ${error.message}`);
            allJsonValid = false;
        }
    } else {
        console.log(`⚠️ ${file} - File not found`);
    }
});

console.log('');

// Test 3: Check seed data structure
console.log('📊 Checking seed data structure...');
const seedDataFiles = [
    { file: 'seed-data/users.json', expectedFields: ['id', 'email', 'displayName', 'username'] },
    { file: 'seed-data/videos.json', expectedFields: ['id', 'userId', 'title', 'videoUrls'] },
    { file: 'seed-data/danmu_comments.json', expectedFields: ['id', 'videoId', 'userId', 'text', 'position'] },
    { file: 'seed-data/notifications.json', expectedFields: ['id', 'userId', 'type', 'title'] },
    { file: 'seed-data/follows.json', expectedFields: ['id', 'followerId', 'followingId'] },
    { file: 'seed-data/activities.json', expectedFields: ['id', 'userId', 'type', 'data'] }
];

let seedDataValid = true;

seedDataFiles.forEach(({ file, expectedFields }) => {
    const filePath = path.join(__dirname, file);
    if (fs.existsSync(filePath)) {
        try {
            const content = fs.readFileSync(filePath, 'utf8');
            const data = JSON.parse(content);
            
            if (Array.isArray(data) && data.length > 0) {
                const firstItem = data[0];
                const hasAllFields = expectedFields.every(field => firstItem.hasOwnProperty(field));
                
                if (hasAllFields) {
                    console.log(`✅ ${file} - ${data.length} records with correct structure`);
                } else {
                    const missingFields = expectedFields.filter(field => !firstItem.hasOwnProperty(field));
                    console.log(`❌ ${file} - Missing fields: ${missingFields.join(', ')}`);
                    seedDataValid = false;
                }
            } else {
                console.log(`❌ ${file} - Empty or invalid array`);
                seedDataValid = false;
            }
        } catch (error) {
            console.log(`❌ ${file} - Error: ${error.message}`);
            seedDataValid = false;
        }
    }
});

console.log('');

// Summary
console.log('📋 Test Summary:');
console.log(`Files: ${allFilesExist ? '✅ All required files present' : '❌ Some files missing'}`);
console.log(`JSON: ${allJsonValid ? '✅ All JSON files valid' : '❌ Some JSON files invalid'}`);
console.log(`Data: ${seedDataValid ? '✅ All seed data valid' : '❌ Some seed data invalid'}`);

console.log('');

if (allFilesExist && allJsonValid && seedDataValid) {
    console.log('🎉 Firestore setup is ready for deployment!');
    console.log('');
    console.log('Next steps:');
    console.log('1. Install dependencies: npm install');
    console.log('2. Deploy database: ./deploy-firestore.ps1');
    console.log('3. Test with Flutter app');
    process.exit(0);
} else {
    console.log('⚠️ Setup has issues that need to be resolved before deployment.');
    process.exit(1);
}
