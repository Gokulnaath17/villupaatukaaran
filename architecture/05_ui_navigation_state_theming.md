# 05 — UI, Navigation, State (GetX), Theming, Localization

Dirs: `lib/ui/*`, `lib/base_class`, `lib/mixins`, `lib/utils/get_localization.dart`, `lang_mapping.dart`.

## 5.1 Tree (`lib/ui/`)

```
home.dart (Home root) | navigator.dart (ScreenNavigationSetup id=1)
utils/theme_controller.dart
player/player.dart + player_controller.dart + components/{standard,gesture,mini,control,albumart_lyrics,lyrics_widget,lyrics_switch,backgroud_image,animated_play_button}
screens/Home/{home_screen,home_screen_controller}
screens/Search/{search_screen,search_screen_controller,search_result_screen(+v2),search_result_screen_controller,components/search_item,desktop_search_bar}
screens/Library/{library,library_combined(+controller),library_controller}
screens/Playlist/{playlist_screen,playlist_screen_controller}
screens/Album/{album_screen,album_screen_controller}
screens/Artists/{artist_screen(+v2),artist_screen_controller}
screens/Settings/{settings_screen,settings_screen_controller,components/custom_expansion_tile}
widgets/~43: bottom_nav_bar, side_nav_bar, scroll_to_hide, sliding_up_panel(vendored), animated_screen_transition, content_list_widget(+item), quickpickswidget, list_widget, song_list_tile, songinfo_bottom_sheet, song_info_dialog, song_download_btn, add_to_playlist, create_playlist_dialog, sort_widget, additional_operation_dialog, modification_list, separate_tab_item_widget, search_related_widgets, up_next_queue, mini_player_progress_bar, piped_sync_widget, link_piped, image_widget, loader, snackbar, cust_switch, modified_text_field, common_dialog_widget, custom_button, lyrics_dialog, sleep_timer_bottom_sheet, backup/restore/export_file/playlist_export/new_version dialogs, playlist_album_scroll_behaviour, shimmer_widgets/*
```

## 5.2 Navigation (`navigator.dart` + `home.dart`)

- `ScreenNavigationSetup{id=1, routes:/homeScreen,/searchScreen,/searchResultScreen,/artistScreen,/albumScreen,/playlistScreen}`; `ScreenNavigation→Navigator(key:Get.nestedKey(1), initial:/homeScreen, onGenerateRoute:GetPageRoute)`; `Key(id)` for Album/Playlist/Artist to force rebuild.
- Push: `Get.toNamed(route,id:1,arguments:...)`; pop: `Get.nestedKey(1).currentState.pop()` (or `Navigator.of.pop` inside detail); `HomeScreenController.whenHomeScreenOnTop()` in `onReady/onClose` updates `isHomeSreenOnTop+playerPanelMinHeight`.
- `Home`: `PopScope(canPop:false)` → panel open?close : nested canPop?pop : tab!=0?go0 : `SystemNavigator.pop/exit(0)+saveSession`; `CallbackShortcuts(space→playPause)`; `Scaffold(bottomNavBar:isBottomNavBarEnabled?ScrollToHide(BottomNavBar):null, endDrawer:desktop/wide?UpNextQueue:null, body:SlidingUpPanel(panel:Player, body:ScreenNavigation, header:MiniPlayer))`; `playerPanelMinHeight` 75 mobile/105 wide + bottom padding.
- Tabs: bottom(4): 0 Home feed,1 Search,2 CombinedLibrary(TabBar Songs/Playlists/Albums/Artists),3 Settings; side/desktop(6): 0 Home,1 Songs,2 Playlists,3 Albums,4 Artists,5 Settings; FAB only `!bottomNav&&(tab0 mobile|tab2)` → search/create-playlist.
- `BottomNavBar→NavigationBar(4 dest)`; `SideNavBar→NavigationRail(<480, rotated labels, 6 dest) else SideBarAnimated(sidebar_with_animation, widthSwitch800, logo icon.png)`; both `Obx(tabIndex)`; `Settings.enableBottomNavBar` flips + persists (forced false desktop).

## 5.3 Screens + flows

- Home (`home_screen.dart` + controller): `ListView[QuickPicksWidget+middle+fixed]` or shimmer or networkError+retry; per-section `ScrollController`s; `loadContent`: Db if `cacheHomeScreenData` else network; stale>8h silent refresh; `loadContentFromNetwork(discoverType QP/TR/TMV/BOLI via getHome/getCharts/getContentRelatedToSong)`; `_setContentList(≥2 items→Album|PlaylistContent)`; `cachedHomeScreenData()`; `changeDiscoverContent`; version dialog.
- Search: `SearchScreen` (rail-back + ModifiedTextField + history vs suggestions + urlPasted banner); controller (`textInput, suggestion/history/urlPasted/focus, Hive searchQuery`, `onChanged→getSearchSuggestion|url detect`, cap10, `ProcessLink.filterLinks`); `SearchResultScreen` (side/mobile: NavigationRail Results+railItems + AnimatedScreenTransition) vs `SearchResultScreenBN` (bottom/desktop: header + ButtonsTabBar+TabBarView); controller (`GetTickerProviderStateMixin`, railIndex, result/separated RxMap, query, railItems Songs/Videos/Albums/Featured/Community/Artists, scrollControllers, tabController, additionalParamNext; `search(args)` + 50%-scroll `getContinuationContents`, `viewAll`, `onSort`).
- Library: `SongsLibraryWidget/PlaylistNAlbumLibraryWidget/LibraryArtistWidget` (SortWidget + List/Grid + ModificationList; empty `noOfflineSong/noBookmarks`; PipedSyncWidget when linked); `CombinedLibrary+Controller` (AppBar library+PipedSync+FAB + TabBar 4); controllers `LibrarySongs (SongsCache+Downloads+housekeeping+sort/search/batch)`, `LibraryPlaylists (initPlst+LibraryPlaylists+piped sync/blacklist/rename/create/importJson+progress)`, `LibraryAlbums/Artists`.
- Player: `Player` (outer SlidingUpPanel queue: UpNextQueue+blur bottom [count+queueLoop+shuffle+clear] + body Standard/Gesture by `playerUi`); components `MiniPlayer` (MiniProgress mobile vs ProgressBar wide + art/marquee + swipe next/prev + play + wide fav/shuffle/prev/loop/lyrics/volume/queue/sleep/download/add/info), `StandardPlayer` (BackgroudImage+blur+gradient + AlbumArtNLyrics+LyricsSwitch+Control portrait/landscape), `GesturePlayer` (fullscreen, h-drag next/prev, double-tap playPause fade, long-press info, glass card), `player_control/albumart_lyrics/backgroud_image(triggers ThemeController.setTheme)/lyrics_widget/switch/animated_play_button`.
- Settings (`settings_screen.dart` 6 `CustomExpansionTile`s: Personalisation[themeMode,language,playerUi,bottomNav,transition,slidable], Content[discover,homeCount,cacheHome,Piped link/unlink+reset blacklist,clearImgCache], Music&Playback[quality,loudness,cache,skipSilence,backgroundPlay(desktop),keepAwake,restoreSession,autoOpen,equalizer,stopOnSwipe,batteryOpt], Download[autoFav,format,download/export paths,export], Backup&Restore, Misc[reset], AppInfo[github,version]; `ThemeSelectorDialog/DiscoverContentSelectorDialog/radioWidget`); controller ~25 Rx prefs + setters persisting `AppPrefs` + side-effects (locale→reload home+hlCode, theme→ThemeController, content→HomeController).
- Detail Album/Playlist/Artist: parallax CachedNetworkImage+shadow + marquee + actions (bookmark/play/enqueue/download/share) + SortWidget + SongListTile(index thumb); Playlist adds rename/remove menu, sync, blacklist, share piped.video vs youtube, export dialog, rearrange; Artist `artist_screen` (Rail variant+About) vs `artist_screen_v2` (TabBar About/Songs/Videos/Albums/Singles); all `Get.put(tag:Key(id).hashCode)`, `onClose→whenHomeScreenOnTop`.

## 5.4 GetX patterns

- DI: `lazyPut fenix:true` singletons + `put permanent` AudioHandler + desktop tray + per-route tagged puts + `delete` on close; `isRegistered` guards.
- Reactive: `.obs/Rx/Rxn/RxList/RxMap` (e.g. `tabIndex0.obs, currentSong Rxn, songList<MediaItem>[].obs, lyrics{}.obs, progressBar{}.obs`); `.value=` + `.refresh()`; `Obx` everywhere, `GetX<T>` when typed, rare `GetBuilder`; `AnimatedScreenTransition(enabled:!transitionDisabled, reverse, horizontal:bottomNav)` keyed `ValueKey(tabIndex)`.
- Routing state: `Get.arguments` (String query, `[bool,dynamic]` artist, `(Album?,id)`, `[Playlist?,id]`), cross-`find`, `Get.context/size/Platform`, `Get.updateLocale`, `Get.dialog/back/isDialogOpen`, `Get.nestedKey`.
- Mixins: `GetSingleTickerProviderStateMixin` (Player,Playlist,Album,CombinedLibrary), `GetTickerProviderStateMixin` (SearchResult,LibraryPlaylists,Artist).

## 5.5 Theming (`ui/utils/theme_controller.dart`)

`ThemeType{dynamic,system,dark,light}`; init from `appPrefs themePrimaryColor/mode`, `onPlatformBrightnessChanged` if system; `setTheme(ImageProvider,songId)` from `BackgroudImage`: `PaletteGenerator(ResizeImage200)→dominant/darkMuted/darkVibrant/lightMuted/lightVibrant→withLightness(0.10) if lum>0.10`, persist, rebuild; `_createThemeData(primarySwatch,titleSwatch,type)`: dynamic dark MaterialColor swatch (canvas700,card600,accents,GoogleFonts.inter,slider/progress/rail/bottomSheet/selection + edgeToEdge light icons); dark black/grey; light white/grey+dark icons; `_createMaterialColor` 10-step; `setWindowsTitleBarColor` via `MethodChannel win_titlebar_color` (350ms delay, Windows guard). Applied `GetX<ThemeController>→AnimatedTheme 700ms` + textScaler clamp; `useMaterial3:false`.

## 5.6 Custom widgets/base/mixin

Lists: `SongListTile+RemoveSongFromPlaylistMixin` (Slidable add/delete|enqueue/playNext, right-click sheet, marquee, playing equalizer), `ContentListWidget/Item` (horizontal 200px cards), `QuickPicks/list/separate_tab_item(ResultWidget)/modification/sort (SortWidgetController/OperationMode{arrange,delete,addToPlaylist,none}/SortType{Name,Date,Duration,RecentlyPlayed})`.
Dialogs: `SongInfoBottomSheet+Controller` (play/next/enqueue/radio/album/artist/share/lyrics/cache/download/add/remove), `add_to_playlist/create_playlist/additional_operation/lyrics/sleep/backup/restore/export_file/playlist_export/new_version/common_dialog/link_piped/piped_sync/song_download_btn`.
Chrome: `bottom/side_nav, scroll_to_hide, animated_screen_transition(slide+fade), playlist_album_scroll_behaviour(no glow), image_widget(cached+Hive thumb), loader, snackbar(BIG/MEDIUM), cust_switch, modified_text_field, custom_button, mini_player_progress_bar, shimmer/*`.
Base `PlaylistAlbumScreenControllerBase` + `AdditionalOpeartionMixin` (see 04).

## 5.7 Localization

Embedded `utils/get_localization.dart:Languages extends Translations keys={lang:{key:value}}` (~51 langs, ~150 keys home/search/library/queueLoop/sleepTimer…); `lang_mapping.dart:langMap` display names; `GetMaterialApp(translations,locale:currentAppLanguageCode??en,fallback:en)`; `"key".tr` incl. dynamic `label.toLowerCase().removeAllWhitespace.tr`; `setAppLanguage→Get.updateLocale+hlCode+reload home`; `getContentHlCode` maps `ia/ga/fj/eo→en`.
