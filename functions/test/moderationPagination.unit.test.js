const test = require('node:test');
const {moderationStore} = require('./helpers/moderation_store');
require('./helpers/moderation_pagination_cases').registerCases(test,async()=>moderationStore());
