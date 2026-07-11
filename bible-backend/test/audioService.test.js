const test = require("node:test");
const assert = require("node:assert/strict");

const { createAudioService } = require("../src/services/audioService");

test("listSongsByLanguage calls YouTube search and returns compact song payload", async () => {
  const originalApiKey = process.env.YOUTUBE_API_KEY;
  process.env.YOUTUBE_API_KEY = "test-youtube-key";

  let capturedUrl = null;
  let capturedOptions = null;
  const service = createAudioService({
    httpClient: {
      async get(url, options) {
        capturedUrl = url;
        capturedOptions = options;

        return {
          data: {
            items: [
              {
                id: { videoId: "video-123" },
                snippet: {
                  title: "Telugu &amp; Worship Songs",
                  thumbnails: {
                    high: { url: "https://img.example/high.jpg" },
                    medium: { url: "https://img.example/medium.jpg" },
                  },
                  channelTitle: "Worship &amp; Praise",
                  publishedAt: "2026-05-24T00:00:00Z",
                },
              },
              {
                id: {},
                snippet: {
                  title: "Missing video id",
                },
              },
            ],
          },
        };
      },
    },
  });

  try {
    const result = await service.listSongsByLanguage("  Telugu  ");

    assert.equal(
      capturedUrl,
      "https://www.googleapis.com/youtube/v3/search"
    );
    assert.deepEqual(capturedOptions.params, {
      part: "snippet",
      type: "video",
      videoCategoryId: "10",
      maxResults: 50,
      q: "Telugu Christian Songs",
      key: "test-youtube-key",
    });
    assert.equal(capturedOptions.timeout, 10000);
    assert.deepEqual(result, [
      {
        id: "video-123",
        title: "Telugu & Worship Songs",
        thumbnail: "https://img.example/high.jpg",
        channelTitle: "Worship & Praise",
        publishedAt: "2026-05-24T00:00:00Z",
      },
    ]);
  } finally {
    process.env.YOUTUBE_API_KEY = originalApiKey;
  }
});

test("listSongsByLanguage logs upstream data and raises a friendly 500", async () => {
  const originalApiKey = process.env.YOUTUBE_API_KEY;
  const originalConsoleError = console.error;
  process.env.YOUTUBE_API_KEY = "test-youtube-key";

  let loggedArgs = null;
  console.error = (...args) => {
    loggedArgs = args;
  };

  const upstreamError = {
    error: {
      code: 403,
      message: "The request cannot be completed because quota is exceeded.",
    },
  };

  const service = createAudioService({
    httpClient: {
      async get() {
        const error = new Error("quota exceeded");
        error.response = { data: upstreamError };
        throw error;
      },
    },
  });

  try {
    await assert.rejects(
      () => service.listSongsByLanguage("Hindi"),
      (error) => {
        assert.equal(error.statusCode, 500);
        assert.equal(
          error.message,
          "Unable to fetch worship audio right now. Please try again later."
        );
        return true;
      }
    );

    assert.deepEqual(loggedArgs, [
      "YouTube API search failed:",
      upstreamError,
    ]);
  } finally {
    console.error = originalConsoleError;
    process.env.YOUTUBE_API_KEY = originalApiKey;
  }
});
