"use strict";

async function captureConsoleErrors(action) {
  const original = console.error;
  const calls = [];
  console.error = (...args) => calls.push(args);
  try {
    return {value: await action(), calls};
  } finally {
    console.error = original;
  }
}

module.exports = {captureConsoleErrors};
