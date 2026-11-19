# Asset hiệu ứng Cổ & Sàn Đấu cho Thú triều Thanh Mao Sơn (Act 1)

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
