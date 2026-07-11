import { createBrowserRouter } from "react-router";
import { Root } from "./Root";
import { Home } from "./screens/Home";
import { BibleLibrary } from "./screens/BibleLibrary";
import { ChapterSelection } from "./screens/ChapterSelection";
import { ReadingScreen } from "./screens/ReadingScreen";
import { Songs } from "./screens/Songs";
import { HymnsPage } from "./screens/Hymns";
import { PlaylistDetail } from "./screens/PlaylistDetail";
import { Profile } from "./screens/Profile";
import { Login } from "./screens/Login";
import { PersonalInformation } from "./screens/profile/PersonalInformation";
import { Notifications } from "./screens/profile/Notifications";
import { Language } from "./screens/profile/Language";
import { Bookmarks } from "./screens/profile/Bookmarks";
import { Favorites } from "./screens/profile/Favorites";
import { Downloads } from "./screens/profile/Downloads";

export const router = createBrowserRouter([
  {
    path: "/login",
    Component: Login,
  },
  {
    path: "/",
    Component: Root,
    children: [
      { index: true, Component: Home },
      { path: "bible", Component: BibleLibrary },
      { path: "bible/:book", Component: ChapterSelection },
      { path: "bible/:book/:chapter", Component: ReadingScreen },
      { path: "hymns", Component: HymnsPage },
      { path: "songs", Component: Songs },
      { path: "playlist/:id", Component: PlaylistDetail },
      { path: "profile", Component: Profile },
      { path: "profile/personal-information", Component: PersonalInformation },
      { path: "profile/notifications", Component: Notifications },
      { path: "profile/language", Component: Language },
      { path: "profile/bookmarks", Component: Bookmarks },
      { path: "profile/favorites", Component: Favorites },
      { path: "profile/downloads", Component: Downloads },
    ],
  },
]);
