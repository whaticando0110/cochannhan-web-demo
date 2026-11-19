# Bố cục duyệt cảnh đội viện trợ ở bìa bãi săn

Hai ảnh sử dụng renderer và sprite của web demo tại `d67b125` trong [PR hậu trại #5](https://github.com/whaticando0110/cochannhan-web-demo/pull/5). Đây là bản dựng tĩnh để duyệt vị trí và khả năng đọc cảnh.

- [Toàn cảnh đội viện trợ bị vây](rung-doi-vien-tro-desktop.png)
- [Khung thử lượt 1 trên mobile](rung-doi-vien-tro-mobile.png)
- [Tọa độ đề xuất dùng chung khi bàn giao](layout.json)

## Cách đọc bố cục

Người chơi từ đường rừng bên trái tiến về bãi săn. Ba cổ sư ở nửa phải, với bốn Điện Lang ép từ trên, dưới và mép phải. Cổ sư áo nâu đỏ phóng Nguyệt Quang dọc đường đất. Cổ sư áo ngà giữ lối cho cả nhóm dịch về khoảng hở đông nam. Con Điện Lang gần giữa ảnh đã tách đàn và quay về người chơi. Đây là con mở trận theo lượt sau tiếng hô **“Cẩn thận!”**.

| Mốc | Tọa độ `(cột, hàng)` đếm từ 0 |
| --- | --- |
| Tiếp tục chạy từ điểm tập kết | `(25, 10)` |
| Bắt đầu thấy đội viện trợ trên tuyến chính | `(27, 10)` |
| Người chơi bị phát hiện trên tuyến chính | `(29, 10)` |
| Điện Lang tách đàn, rồi vào vị trí đánh | `(34, 9)` → `(32, 10)` |
| Ba cổ sư giữ hậu và mở khe | `(35, 8)`, `(35, 10)`, `(36, 11)` |
| Khe thoát | Men qua `(37, 10)` rồi xuống `(37, 11)` và tiến đến `(38, 11)` |
| Đội trưởng đứng sau khi phá vây | `(37, 11)`. Người chơi nói chuyện từ `(36, 11)`. |

Vùng trận dành cột **27–34**, hàng **5–14**. Bản mặt bằng mở rộng hai mép dọc của vùng dự kiến để nhận cả đường tiếp cận lệch khỏi lối đất chính. Trên mobile, khung lượt tập trung vào người chơi, đối thủ và vùng báo đòn. Dấu **Ô né** trong ảnh nằm ở `(30, 9)`, hợp lệ theo lưới thật.

## Kiểm tra mặt bằng

- Đã xác minh 10 vị trí có thể đi tới trên cột phát hiện. Mẫu đặt sói lệch hàng theo đường tiếp cận cho ra ít nhất một ô né hợp lệ ở cả 10 vị trí.
- Khe thoát gồm 5 ô tiếp giáp và đi được, với phần đường sau ô xuất phát nằm ngoài vị trí đàn sói. Từ cả 74 ô đi được của vùng đánh đều có đường tới ô nói chuyện sau khi nhóm đã tụ lại.
- Với vị trí mẫu, luật Đấu nhanh hiện có chạy được chuỗi né → hai lần phóng Nguyệt Quang, thắng ở lượt 3. Số liệu phục vụ duyệt mặt bằng và cân bằng mốc đầu.
- Ảnh desktop 1120 × 824 và ảnh mobile 390 × 844 được chụp trong Edge. Vùng đỏ và ô né lấy từ luật, còn lớp chú thích dùng để duyệt.

## Bàn giao cho Gemini sau duyệt

Dùng cùng vị trí, asset hiện có và tỷ lệ trong hai ảnh. Làm ba đoạn ngắn theo thứ tự. Đầu tiên, đội bị ép rồi mở khe đông nam. Tiếp theo, Điện Lang tách đàn đứng lại, hướng về người chơi và lấy đà tại vị trí mở trận. Cuối cùng, đội tụ tại chỗ nói chuyện khi trận kết thúc. Trong mỗi đoạn, ghi mã vai, điểm chân, hướng quay, thời lượng và điểm phát hoặc nhận hiệu ứng.

Codex bổ sung logic phát hiện, lượt chiến đấu và các mốc lưu theo mặt bằng được duyệt. Gemini bàn giao clip và hiệu ứng của cảnh rừng trên nhánh asset riêng.
