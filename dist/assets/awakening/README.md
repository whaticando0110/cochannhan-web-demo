# Asset Đại điển Khai Khiếu (Hang Nguyệt Lan)

Bộ pixel art do Antigravity dựng cho màn **Đại điển Khai Khiếu** trên nền hang đá vôi `#101a24`–`#355553`, bám mô tả **Chương 4–5** (*Cổ Chân Nhân*): biển hoa **Nguyệt Lan** bên kia sông ngầm (cánh hoa xanh lam nhạt cong như trăng non, cành ngọc, nhụy ngọc lóng lánh) và **Hy Vọng Cổ** (đốm sáng vàng ấm bay lên rồi hội tụ).

## Tệp trong gói

| Tệp | Kích thước | Quy cách neo & khung |
| :--- | :--- | :--- |
| [nguyet-lan-tiles.png](nguyet-lan-tiles.png) | `128×32` PNG trong suốt | 4 kiểu `32×32` xếp ngang (`x = 0, 32, 64, 96`), **neo tâm chân dưới** `(16, 31)`, alpha nhị phân `0/255`. |
| [hy-vong-gu.png](hy-vong-gu.png) | `64×16` PNG trong suốt | 4 khung bay `16×16` xếp ngang (`x = 0, 16, 32, 48`), chu kỳ lặp `180 ms/khung`, alpha nhị phân `0/255`. |
| [awakening-assets.json](awakening-assets.json) | JSON | Tọa độ từng ô, điểm neo và bounding-box đã kiểm từng pixel. |
| [awakening-preview.png](awakening-preview.png) | `600×682` PNG | Bảng duyệt `4×` trên nền caro/vườn tối, bản `1×` và cảnh ghép thử hoàn chỉnh `9` hàng hang đá vôi `2×` kèm Huyền bào. |
