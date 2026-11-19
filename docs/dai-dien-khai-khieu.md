# Đại điển Khai Khiếu

Hang Nguyệt Lan có bờ chờ gia lão, sông ngầm xanh và biển hoa nằm về phía linh tuyền. Hoa Nguyệt Lan có cánh xanh lam nhạt dáng trăng non. Khi thí sinh đi sâu, Hy Vọng Cổ bay lên từ biển hoa rồi tụ vào người. [Chương 4](https://truyenhoan.com/co-chan-nhan/chuong-4.html) · [Chương 5](https://vnthuquan.org/TacPham/co-chan-nhan-25730/chuong-5)

| Độ sâu sau khi qua sông | Tư chất |
| --- | --- |
| 0–9 bước | Chưa khai khiếu |
| 10–19 bước | Đinh |
| 20–29 bước | Bính |
| 30–39 bước | Ất |
| 40–49 bước | Giáp |

Bản dịch chương 5 mô tả các khoảng liên tiếp. Game xếp bước đúng ranh giới vào đẳng mới và đặt cuối lối đi ở bước 49. Phương Nguyên dừng ở bước 27. Phương Chính đạt Giáp ở bước 43. [Chương 5](https://vnthuquan.org/TacPham/co-chan-nhan-25730/chuong-5) · [Chương 6](https://truyenhoan.com/co-chan-nhan/chuong-6.html)

Demo dùng mỗi ô sâu hơn theo trục hướng vào linh tuyền làm một bước tư chất. Chỉ xét độ sâu lớn nhất, nên bước ngang hoặc quay lại giữ nguyên kết quả. Người chơi đi xuyên qua các cụm Hy Vọng Cổ trong biển hoa để tụ ánh sáng Không Khiếu và tiến xa hơn trước khi áp lực Linh Tuyền buộc dừng lại, hoặc chủ động chốt kết quả bất cứ lúc nào từ bờ hoa. HUD hiển thị độ sâu, bậc tư chất Đinh–Giáp và số cụm Hy Vọng Cổ đã tụ (không hiện thanh chỉ số áp lực thô).

Mở demo để chọn Huyền bào hoặc Áo rêu rồi vào hang. Năm đoạn *Nhân Tổ truyện* (diễn ý theo chương 5) tự chuyển dần ở dải chữ phía dưới màn chơi theo bước tiến của nhân vật, không khóa điều khiển bàn phím hay chạm ô. Nhân vật đã chọn và độ sâu đạt được được gắn vào tham số `?hero=...&depth=...` kèm lưu phiên tạm khi trở về Sơn Trại. [Chương 5](https://vnthuquan.org/TacPham/co-chan-nhan-25730/chuong-5)

Màn chơi dùng bộ pixel hang động, Nguyệt Lan (`128×32`) và Hy Vọng Cổ (`64×16`) vẽ chuẩn `1:1` trên lưới `32px` và sắp lớp theo trục Y quanh nhân vật. Áo rêu dùng lại các khung đứng, đi bộ và thế thủ của bộ nữ Cổ sư trong dự án game.
