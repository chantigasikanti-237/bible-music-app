const { songRepository } = require("../repositories/songRepository");

const createSongService = ({
  songs = songRepository,
} = {}) => ({
  async listSongs(query) {
    const languageCode = String(query.language || query.languageCode || "")
      .trim()
      .toLowerCase();
    const search = String(query.search || query.q || query.title || "").trim();

    return songs.listSongs({
      languageCode: languageCode || null,
      search: search || null,
      limit: query.limit,
      cursor: query.cursor,
      page: query.page,
    });
  },
});

module.exports = {
  createSongService,
  songService: createSongService(),
};
