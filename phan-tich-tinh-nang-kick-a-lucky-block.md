# Phan tich tinh nang game: Kick a Lucky Block

## 1) Tong quan gameplay core loop
- Nguoi choi kick Lucky Block de roll ra "brainrot"/vat pham.
- Trong qua trinh kick co the trigger weather/event (vi du tsunami theo mo ta place).
- Vat pham thu duoc co the dat len plot de tao thu nhap (coins) theo thoi gian.
- Nguoi choi ban/doi/thu thap de toi uu hoa thu nhap va kick power.
- Dung tien mua weights va nang cap toc do/luc kick de kick xa hon va farm nhanh hon.

## 2) He thong block, mo block, thu thap, ban
- Mo Lucky Block: `rev_LB_OpenRequest`, `rev_lb_open`, `rev_open_random`.
- Kick va chuoi su kien kick: `rev_KickEvent`, `rev_KickCollect`, `rev_KickEventEnded`, `rev_KickData`, `rev_KickZman`.
- Thu thap vat pham: `rev_B_Collect`, `rev_Collected`.
- Ban vat pham:
  - Ban tung mon: `ref_B_Sell`, `rev_B_Sell`.
  - Ban tat ca: `ref_B_SellAll`.

## 3) Kinh te & chi so
- Coins/cap nhat coin: `rev_CoinsChanged`.
- He so coin: `rev_CoinsMulti`.
- Chi so kick multiplier: `rev_KickMulti`.
- Chi so speed/weight:
  - Speed: `rev_SPEED_UPDATE`, `rev_SPEED_MULTIPLIER`, `rev_SPEED_UPGRADE`.
  - Weight: `rev_Weight_Update`, `rev_Weight_Multi`, `rev_WeightBonus`, `rev_WeightEquip`, `rev_EquippedWeight`, `rev_TaviMishkal`.

## 4) Progression
- Nang cap block/player: `rev_B_Upgrade`, `rev_bs_upgrade`, `rev_bs_updateClient`.
- Rebirth: `rev_RebirthRequest`, `rev_RebirthUpdate`.
- Tutorial: `rev_TutorialStep`, `rev_TU_upd`.
- Danh muc/index/favorite:
  - Index update: `rev_IndexUpdate`.
  - Toggle favorite: `rev_ToggleFav`.

## 5) Plot, dat vat pham, transform
- Quan ly plot: `rev_PlotAdded`.
- Tuong tac object tren scene: `rev_S_Interact`.
- Co che "steal": `rev_S_Steal`.
- Bien hinh/hoan nguyen: `rev_Transformed`, `rev_Reverted`.

## 6) Event he thong & weather
- Weather update: `rev_WeatherUpdate`, `rev_AddedWeather`, `rev_RemovedWeather`.
- VFX update: `rev_VFX_UPD`.
- Thong diep he thong: `rev_PlayMessage`, `rev_NotificationUpdate`.

## 7) Spin/Gacha/Pack
- Yeu cau spin: `rev_RequestSpin`.
- Thuc hien spin: `rev_SpinWheel`.
- Cap nhat luot spin: `rev_UpdateSpins`.
- Pack data: `rev_PackData`.

## 8) Shop, IAP, uu dai
- Mua trong shop: `rev_Shop_Buy`.
- GUI cho thay cac goi nhu `x2Cash`, `MegaLuck`, `VIP`, `ServerLuck`, `LuckyBlock`.
- Claim free/group:
  - Free claim/check: `rev_ClaimFree`, `rev_CheckFree`.
  - Group claim/check/response: `rev_GroupClaim`, `rev_GroupClaimCheck`, `rev_GroupClaimResponse`.

## 9) Offline rewards & AFK-like economy
- Offline reward update/claim/force: `rev_Offline_Update`, `rev_Offline_Claim`, `rev_Offline_Force`.

## 10) Social features
- Trading day du: `rev_trade_start`, `rev_trade_i`, `rev_trade_n`, `rev_trade_s`, `rev_trade_u`, `ref_trade_r`.
- Friend bonus/cap nhat ban be: `rev_CheckFriend`, `rev_FriendsUPD`.
- Leaderboard update: `rev_LeaderboardUPD`.

## 11) Market features
- MyMarket data/stock/gift:
  - `rev_myMarket_data`
  - `rev_myMarket_stock`
  - `rev_myMarket_gift`

## 12) UI/UX systems phat hien duoc
- Trading GUI day du (selection, invite, accept/decline).
- Notification GUI.
- Surface GUI trong world.
- Cmdr admin console (`Cmdr`) ton tai trong game.
- Importing GUI va cac popup monetization.

## 13) Cong cu admin/moderation (noi bo)
Trong `ReplicatedStorage` co bo Cmdr command (khong phai player feature thong thuong), gom cac command dang quan tri nhu:
- `AddCoins`, `AddMultiplier`, `AddWeather`
- `GiveBrainrot`, `GivePack`
- `GlobalLuck`, `GlobalMultiplier`, `GlobalPack`, `GlobalBrainrot`
- `InitRestart`, `Message`, `Fly`, `Jail`, `Luckyfy`, `Biggify`

## 14) Danh gia kien truc
- Game dung mo hinh remote-centric, server-authoritative cho economy/progression.
- Co day du tru cot cua simulator/tycoon:
  - Farm loop
  - Upgrade + rebirth
  - Trading + social
  - Event weather + VFX
  - Monetization + free reward
- Co dau hieu live-ops manh (global effects, notification, weather events, pack/spin updates).

## 15) Gioi han phan tich
- `script_grep` bi timeout tren game nay nen khong decompile/quet het source script.
- Phan tich duoc xay dung tu:
  - Place description
  - CAY instance (Workspace/ReplicatedStorage/StarterGui)
  - Danh sach remote event/function
  - Remote spy runtime logs
- Vi vay, day la ban phan tich tinh nang o muc he thong/hanh vi quan sat duoc, khong phai reverse source code 100%.
