# Asset hiệu ứng Cổ & Sàn Đấu cho Thú triều Thanh Mao Sơn (Act 1)

## Tích hợp cảnh Cuồng Điện Lang

- Atlas `cuong-dien-lang-motion.png` có 17 tư thế. Dùng mẫu đứng Cuồng Điện Lang có sẵn và 16 tư thế mới tạo bằng ImageGen dựa trực tiếp trên mẫu đó. Dựng `4 × 5` ô `160 × 112`, đường chân `y = 100` với hai khung chạy bay nâng nhẹ khỏi đất. Các hàng lần lượt là phi nước đại, ghìm chân và gầm, lấy đà và húc, trúng đòn và phản kích, cùng tư thế đứng gốc. Ở cỡ chơi, thân dài khoảng 5 ô.
- Tĩnh Nghi dùng [atlas ở PR #4](https://github.com/whaticando0110/cochannhan-web-demo/pull/4) và [file Aseprite có thể chỉnh sửa](art/tinh-nghi-motion.aseprite). Tăng nhịp bốn khung đi khi bà lao lên thang. Huyết Nguyệt rời lòng bàn tay ở khung `cast[4]`, sau 330 ms tụ thế. Phản ứng trúng đòn bắt đầu khi lưỡi nguyệt chạm vai.
- Cảnh dùng Kim Chung Tráo theo quy ước Tam chuyển của demo. Vòm chuông dựng trước khi thú vương phản kích, rồi dùng quầng vàng và tia va chạm của Antigravity tại điểm trúng. Chế độ giảm chuyển động giữ camera cố định và tắt rung, chớp. Kết thúc cảnh, Tĩnh Nghi ở lại trên lũy.

## Asset Antigravity

Tài liệu kỹ thuật trên nhánh `antigravity/gu-vfx-thu-trieu` phục vụ Issue #2 (`whaticando0110/cochannhan-web-demo`). Phần chuyển động nhân vật Cổ Nguyệt Tĩnh Nghi do Codex phụ trách trên `codex/web-tinh-nghi-motion` (PR #4, base `antigravity/thu-trieu-assets` tại `18dc497`).

## 1. Huyết Nguyệt (`dist/assets/rampart/huyet-nguyet.png` + `huyet-nguyet.json`)

- **Nguồn chuẩn**: Tách từ `previews/gu-vfx-static-v1/huyet-nguyet/HUYET_NGUYET_VFX_RAW.png` (commit `cb8b369f`), chỉnh pivot `(40, 38) -> (32, 32)` trong từng ô `64 × 64` không cắt xén, alpha nhị phân `0 | 255`.
- **Kích thước & lưới**: `512 × 320` (`8 cột × 5 hàng`, ô `64 × 64`), quy ước quay phải (`facing: "right"`).
- **Bố cục hàng**: Hàng 0 = `flight` (`8` khung), Hàng 1 = `impact_slash` (`0..3`) + `impact_block` (`4..7`), Hàng 2 = `cast` (`6` khung), Hàng 3 = `bleed_tick` (`6` khung), Hàng 4 = `blood_trail` (`4` khung).

## 2. Kim Chung Tráo (`dist/assets/rampart/kim-chung-trao.png` + `kim-chung-trao.json`)

- **Nguồn chuẩn**: Tách từ `previews/gu-vfx-static-v1/kim-chung-trao/KIM_CHUNG_TRAO_VFX_RAW.png` (commit `cb8b369f`), giữ nguyên `sourceSize` `96 × 96` và tâm chân mặt đất `groundPivot: [48, 82]`, alpha nhị phân `0 | 255`.
- **Kích thước & lưới**: `768 × 480` (`8 cột × 5 hàng`, ô `96 × 96`), dùng chung cho Tam chuyển và Tứ chuyển (`supportedRanks: [3, 4]`).
- **Bố cục hàng**: Hàng 0 = `cast` (`6` khung), Hàng 1 = `sustain_back` (`8` khung, `under-actor`), Hàng 2 = `sustain_front` (`8` khung, `over-actor`), Hàng 3 = `block` (`6` khung), Hàng 4 = `shatter` (`6` khung).

## 3. Rung Sàn Đấu Khi Thú Vương Tới (`dist/assets/rampart/tremor-dust.png` + `tremor-dust.json`)

- **Kích thước & lưới**: `512 × 128` (`8 cột × 2 hàng`, ô `64 × 64`, `groundPivot: [32, 46]`, alpha nhị phân `0 | 255`).
- **Bố cục hàng**:
  - Hàng 0 (`ground_shock`, `8` khung): Vết nứt đất, sóng bụi chấn động lan tròn và sỏi đá bật nảy theo quỹ đạo parabol khi Cuồng Điện Lang dậm bước.
  - Hàng 1 (`thunder_quake`, `8` khung): Hồ quang điện lam toác mặt đất khi Thú Vương gầm / đáp xuống trước lũy tây.
- **Hàm điều khiển**: `BEAST_KING_TREMOR_STEPS`, `buildTremorKeyframes()`, `playBeastKingTremor()` trong `dist/rampart-fx.mjs`.

## 4. Kim Chung Tráo Lóe Sáng + Anime Impact Frame (`dist/assets/rampart/kim-chung-impact.png` + `kim-chung-impact.json`)

- **Kích thước & lưới**: `768 × 288` (`8 cột × 3 hàng`, ô `96 × 96`, khớp 1:1 với `kim-chung-trao.png`, `groundPivot: [48, 82]`, tâm chạm đòn `contactPoint: [62, 52]`, alpha nhị phân `0 | 255`).
- **Bố cục hàng**:
  - Hàng 0 (`anime_impact`, `8` khung):
    - Khung `0` (`45 ms` — **Anime Impact Frame A**): Đảo tương phản đen-trắng gắt kèm tia tốc độ đen xuyên tâm và chớp chéo cắt ngang vòm chuông.
    - Khung `1` (`45 ms` — **Anime Impact Frame B**): Đảo âm bản nền tối kèm chùm tia kim-bạch và gân chuông phát sáng.
    - Khung `2..3` (`55 ms/khung` — **Lóe sáng hoàng kim / Bell Golden Flash**): Quầng sáng trắng-vàng ôm kín đỉnh và thân chuông kèm sao chớp tại điểm chạm.
    - Khung `4..7`: Dư quang chuông và tàn ấn văn vàng phát tán.
  - Hàng 1 (`sonic_ripple`, `8` khung): Sóng âm chuông đồng 6 múi cộng hưởng lan rộng kèm vòng xung kích mặt đất.
  - Hàng 2 (`claw_clash`, `8` khung): Vệt trảo lôi điện của Thú Vương va vào vách chuông và tia lửa bật ngược.
- **Hàm điều khiển**: `buildAnimeImpactSchedule()`, `createKimChungDefense()` trong `dist/rampart-fx.mjs` kết hợp lớp `.anime-impact-a`, `.anime-impact-b`, `.bell-bloom` trong `dist/rampart-fx.css`.

## 5. Hiệu Ứng Xuất Cổ, Dư Ảnh Đường Bay & Chớp Va Chạm (`dist/assets/rampart/gu-cast-fx.png` + `gu-cast-fx.json`)

- **Kích thước & lưới**: `512 × 320` (`8 cột × 5 hàng`, ô `64 × 64`, `pivot: [32, 32]`, `facing: "right"`, alpha nhị phân `0 | 255`).
- **Bố cục hàng**:
  - Hàng 0 (`moonlight` — Nguyệt Quang): Cột `0..3` = `moonlight_release` (khí kình xuất chưởng lam băng); Cột `4..7` = `moonlight_wake` (cặp dư ảnh trăng non & hạt sương lạnh).
  - Hàng 1 (`whirl` — Nguyệt Toàn): Cột `0..3` = `whirl_release`; Cột `4..7` = `whirl_wake` (dải xoáy chữ S ngọc bích).
  - Hàng 2 (`needles` — Tùng Châm): Cột `0..3` = `needles_release`; Cột `4..7` = `needles_wake` (luồng gió lá thông xanh lục).
  - Hàng 3 (`blood` — Huyết Nguyệt): Cột `0..3` = `blood_release`; Cột `4..7` = `blood_wake` (dư ảnh huyết nguyệt răng cưa & giọt máu tản xạ).
  - Hàng 4 (`common`): Cột `0..3` = `foot_dust` (bụi gió dạt ngược dưới chân cổ sư khi xuất chiêu, `groundPivot: [32, 52]`); Cột `4..7` = `hit_flash` (sao chớp 8 cánh xác nhận trúng đích).
- **Hàm điều khiển**: `buildGuWakeSchedule()`, `spawnEnhancedGuCast()`, `spawnEnhancedGuImpact()` trong `dist/rampart-fx.mjs`.

## 6. Rương Tiếp Tế & Hiệu Ứng Hấp Thụ Nguyên Thạch (`primeval-stone.png` + `stone-absorb-fx.png`)

- **Căn cứ nguyên tác**: *Cổ Chân Nhân* Chương 6–7 — Nguyên thạch hình bầu dục cỡ trứng vịt, sắc xám tro (`thanh hôi sắc`), ẩn chứa thiên địa nguyên khí dày đặc; khi cổ sư rút cạn nguyên khí đưa vào Không Khiếu thì vỏ đá nứt vỡ, hóa thành một nắm bột phấn xám rơi khỏi kẽ tay.
- **Rương tiếp tế & Icon Nguyên Thạch (`dist/assets/rampart/primeval-stone.png` + `primeval-stone.json`)**:
  - Kích thước & lưới: `256 × 128` (`4 cột × 2 hàng`, ô `64 × 64`, `groundPivot: [32, 54]`, alpha nhị phân `0 | 255`).
  - **Tách riêng ô đặt thùng và ô nhân vật đứng**:
    - Ô nhân vật đứng hấp thụ (`SUPPLY_STAND_POST` / `SUPPLY_POST`): `col 9, row 13` (nhân vật quay mặt sang phải `--face: 1` về phía thùng).
    - Ô đặt thùng nguyên thạch (`SUPPLY_CRATE_POST`): `col 10, row 13` (ô kế bên phải trên sân đá, tách khỏi chân cầu thang `col 6..7, row 11.5..13.5` và tách khỏi lộ trình cổ sư tiếp viện đi lên `(8, 14) -> (8, 12) -> (6, 12) -> (4, 11)` để không ai dẫm lên thùng gỗ).
  - Hàng 0 (`supply_crate`, `4` khung): Khung `0..2` = rương gỗ nẹp đồng mở nắp với các viên nguyên thạch xám bầu dục thở nhịp nguyên khí xanh ngọc; Khung `3` = trạng thái sau khi đã lấy & hút cạn 1 viên, còn vương bột đá xám trên miệng rương.
  - Hàng 1 (`stone_icon`, `4` khung): Icon viên nguyên thạch cho HUD `#stone-status` (`dormant -> awakening -> cracking -> powder`).
- **Hiệu ứng Hấp Thụ Nguyên Thạch (`dist/assets/rampart/stone-absorb-fx.png` + `stone-absorb-fx.json`)**:
  - Kích thước & lưới: `512 × 128` (`8 cột × 2 hàng`, ô `64 × 64`, `groundPivot: [32, 54]`, `dantianCenter: [32, 34]`, tổng thời lượng `1500 ms` khớp `ABSORB_MS = 1500`, alpha nhị phân `0 | 255`).
  - Hàng 0 (`qi_spiral_over`, lớp `over-actor`): Khung `0..1` = viên nguyên thạch trước ngực/đan điền bừng sáng vân ngọc; Khung `2..4` = hai dải thiên địa nguyên khí xanh ngọc xoắn kép vào Không Khiếu; Khung `5` = Không Khiếu lóe sáng vòng Thanh Đồng Nguyên Hải đầy ắp, vỏ nguyên thạch nứt đôi; Khung `6..7` = viên đá vỡ vụn thành thác bột phấn xám trắng rơi lả tả xuống đất.
  - Hàng 1 (`ground_ring_under`, lớp `under-actor`): Vòng cộng hưởng nguyên khí dưới chân (`0..5`) chuyển sang vòng bụi bột đá xám lắng xuống nền đá (`6..7`).
- **Hàm điều khiển**: `buildStoneAbsorptionSchedule()`, `createSupplyStationFx()` trong `dist/rampart-fx.mjs` (hỗ trợ `cancelAbsorption()` khi người chơi bước đi giữa chừng mà chưa làm vỡ viên nguyên thạch).

## 7. Chuyển Động Di Chuyển Cổ Sư Tiếp Viện (`dist/assets/rampart/guard-ivory-motion.png` + `guard-ivory.json`)

- **Kích thước & lưới**: `512 × 256` (`4 cột × 2 hàng`, ô `128 × 128`, `backgroundSize: "400% 200%"`, `facing: "right"`, `anchorBaselineY: 121`, lưới pixel gộp `2 × 2` chuẩn `1x1-detail = 0`, alpha nhị phân `0 | 255`).
- **Bố cục hàng**:
  - Hàng 0 (`cast`, `4` khung, `durationMs: 690`, `timesMs: [0, 110, 330, 475]`): Giữ nguyên bit-for-bit 4 khung xuất chưởng Nguyệt Quang của `guard-ivory.png` cùng tọa độ bàn tay `chargePalm128: [67, 68]`, `releasePalm128: [94, 64.5]`.
  - Hàng 1 (`walk`, `4` khung, `durationMs: 600`, `timesMs: [0, 160, 300, 460]`): Chu kỳ bước đi 4 nhịp học theo chuẩn `tinh-nghi-motion.png` của Codex — khung `0, 2` bước chân chạm đất mũi hài hơi nhấc và gót sau đẩy, khung `1, 3` chân trụ nâng thân nhấp nhô `2px` (`y0: 46 -> 44`), tà bạch bào và đai lam xám tách nhịp lộ quần trong, tay áo vung tự nhiên, giữ nguyên 100% đầu/búi tóc/khuôn mặt/cổ áo của `guard-ivory[0]`.
- **Hàm điều khiển & CSS**: `RELIEF_WALK_TIMES_MS`, `RELIEF_WALK_DURATION_MS`, `buildReliefWalkKeyframes()`, `createReliefGuardMotion(unit, reducedMotion)` trong `dist/rampart-fx.mjs` và `.ivory-guard.relief-guard.relief-moving .guard-art` trong `dist/rampart-fx.css`.

## 8. Ba Nhịp Chuyển Động & Hiệu Ứng Cảnh Rừng Phá Vây (`forest-ambush-motion.mjs` + `choreography.json`)

- **Atlas di chuyển cho hai cổ sư viện trợ còn lại**:
  - `dist/assets/rampart/guard-russet-motion.png` + `guard-russet.json` (`512 × 256`, `4 × 2` ô `128 × 128`, `anchorBaselineY: 121`, lưới `2 × 2` chuẩn `0` mixel, alpha `0 | 255`): Hàng 0 khớp bit-for-bit với `guard-russet.png` (`chargePalm128: [67.5, 69.5]`, `releasePalm128: [96, 63.5]`), Hàng 1 là chu kỳ đi bộ 4 khung (`600 ms`).
  - `dist/assets/rampart/guard-slate-motion.png` + `guard-slate.json` (`512 × 256`, `4 × 2` ô `128 × 128`, `anchorBaselineY: 119`, lưới `2 × 2` chuẩn `0` mixel, alpha `0 | 255`): Hàng 0 khớp bit-for-bit với `guard-slate.png` (`chargePalm128: [88, 56]`, `releasePalm128: [108, 65]`), Hàng 1 là chu kỳ đi bộ 4 khung (`600 ms`) của Đội trưởng.
- **Atlas Hiệu Ứng Cảnh Rừng (`dist/assets/rampart/forest-ambush-fx.png` + `forest-ambush-fx.json`)**:
  - Kích thước & lưới: `512 × 192` (`8 cột × 3 hàng`, ô `64 × 64`, `backgroundSize: "800% 300%"`, alpha nhị phân `0 | 255`).
  - Hàng 0: Cột `0..3` = `detection_glint` (ánh mắt sói lóe đỏ-vàng phát hiện người chơi ở cột `29`); Cột `4..7` = `pounce_coil_dust` (móng sói cào bật đất mùn & lá khô khi ghìm chân lấy đà ở `(32, 10)`).
  - Hàng 1: Cột `0..3` = `fang_ward_spark` (tia lửa va chạm giữa nanh vuốt Điện Lang và hộ thân của đội viện trợ); Cột `4..7` = `gap_blast_wave` (sóng xung kích Nguyệt Quang và lá rừng tản xạ dọc đường đất `(35, 10) -> (38, 10)` khi mở khe thoát).
  - Hàng 2: Cột `0..3` = `urgent_step_dust` (bụi đất và lá khô dưới chân cổ sư khi rút qua khe Đông Nam); Cột `4..7` = `regroup_stance_ring` (vòng tín hiệu tụ quân ở `(37, 11)` và ô đối thoại `(36, 11)`).
- **Ba đoạn chuyển động (`docs/forest-ambush/choreography.json` & `dist/forest-ambush-motion.mjs`)**:
  1. `segment1_breakout` (`2200 ms`, kích hoạt tại `(27, 10)`): `cover` (`slate-guard` ở `(35, 8)`), `opens-gap` (`russet-guard` ở `(35, 10)`) và `rear-guard` (`ivory-guard` ở `(36, 11)`) đánh bật 4 Điện Lang bao vây, `russet-guard` phóng Nguyệt Quang đẩy lùi sói đông `(38, 10)`, cả đội bước qua khe thoát `[[35, 10], [36, 10], [37, 10], [37, 11], [38, 11]]`.
  2. `segment2_scout_alert` (`1450 ms`, kích hoạt tại cột `29` `(29, 10)`): Điện Lang tách đàn ở `(34, 9)` lóe `detection_glint` sau tiếng hô *"Cẩn thận!"*, phi nước đại (`run[4..7]`) sang `(32, 10)`, ghìm móng cào đất (`pounce_coil_dust`) và hạ thấp thân lấy đà (`frame 8`) mở trận theo lượt (ô né hợp lệ tại `(30, 9)`).
  3. `segment3_regroup` (`1650 ms`, khi hạ xong Điện Lang tách đàn): Sói gục tại `(32, 10)`, ba cổ sư bước về tụ hội tại điểm hẹn (`regroupLead: (37, 11)`, hai cánh `(38, 10)` và `(38, 12)`) kèm vòng `regroup_stance_ring` đón người chơi tới `talkFrom: (36, 11)`.
