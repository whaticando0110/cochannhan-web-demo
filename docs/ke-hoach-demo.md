# Kế hoạch roguelike Godot · Vượt Thanh Mao

Ba trận của chương đầu luyện ba kỹ năng theo thứ tự. Đọc vùng báo đòn, tận dụng địa hình, rồi quản lý chân nguyên trước trùm. Đợt đầu dùng hai tuyến đã có để thử địa hình và các kiểu dùng Cổ trước khi mở chương kế.

| Màn | Thử thách và quyết định | Cổ hoặc vật phẩm xuất hiện |
| --- | --- | --- |
| Đại điển Khai Khiếu | Đi qua sông và biển Nguyệt Lan, nhận tư chất và sức chứa chân nguyên. Sau khi gục có thể giữ kết quả cũ để vào lượt mới. | Hy Vọng Cổ xuất hiện trong nghi lễ. Nguyệt Quang là Cổ đánh đầu tiên sau Đại điển. |
| Rìa rừng Thanh Mao | Học né vùng vồ, đánh kề, thủ thế để hồi chân nguyên. Thắng trận chọn tuyến và cân nhắc hồi sức hay lấy thêm cách đánh. | Nguyệt Quang có từ đầu. **Ngọc Bì Cổ** là một lựa chọn thưởng trước màn hai. |
| Khe đá Hoang Nha | Tìm góc bắn vì vách đá chặn Nguyệt Quang. Ba bố cục đặt vách ở ba vị trí khác nhau trên đường bắn ban đầu. | Chọn một lá **Sinh Cơ Diệp** mang vào hang hoặc chọn phần thưởng hồi phục giữa màn. |
| Lối săn tinh anh | Tinh anh luân phiên vồ vùng quanh mục tiêu và lao một hàng. Có lượt đổi vị trí giữa hai đòn nặng. | Mở rộng Nguyên Hải nằm trong nhóm thưởng riêng của tuyến. |
| Điểm nghỉ trước hang | Chọn hồi tối đa 8 sinh lực, hồi 1 chân nguyên hoặc đi tiếp. Mỗi lượt chơi chỉ chọn một lần, có xem trước chỉ số. | Sinh Cơ Diệp dùng trong trận. Ngọc Bì Cổ giữ quyền sử dụng qua các màn, lớp ngọc hết khi chuyển trận. |
| Hang Cuồng Điện Lang | Vồ vùng và quét hành lang dùng dấu khác nhau. Trùm hồi thế sau mỗi đòn nặng. Dưới nửa sinh lực, nó đổi thứ tự đòn và có thể ra đòn nặng ngay khi hết hồi thế. | Màn kết quả ghi đường đi, chiến lợi phẩm và tài nguyên còn lại. |
| Sườn đá Mù Sương | Màn đầu Nhị chuyển có ba bố cục. Điện Lang phóng lôi khóa một ô khi có đường ngắm, rồi hồi thế một lượt. Vách đá chặn đòn tầm xa của hai bên. | Chọn **Nguyệt Mang Cổ**, **Bạch Ngọc Cổ** hoặc **Tứ Vị Tửu Trùng** và ghép với một Cổ Nhất chuyển. Hai Cổ cùng hệ mở hiệu ứng bộ. |
| Bãi Đá Suối Sấm | Vào sau Sườn đá Mù Sương. Điện Lang dẫn lôi luân phiên nhiễm điện vùng nước nông theo bố cục và bắn Hồ quang vào một ô. Mỗi đòn lôi có một lượt hồi thế. Vách đá chặn Hồ quang. | Điểm nghỉ cho hồi tối đa 20 sinh lực và 3 chân nguyên, giữ số lá còn lại và cho đổi một trong chín bộ. |

## Luật để thử

- Trong lượt chơi, giữ **hai khe Cổ**, gồm một khe công và một khe tùy chọn cho bản cân bằng đầu. Có một khe vật phẩm tiêu hao. Thủ thế, di chuyển và tay không là hành động cơ bản.
- Đề xuất **Ngọc Bì** tốn 1 chân nguyên, dùng một hành động để chặn tối đa 5 sát thương của đòn kế tiếp trong hai lượt. Tác dụng còn lại hiện rõ trên HUD. Nếu vừa thủ thế vừa có lớp ngọc, áp dụng thủ thế trước rồi trừ lớp ngọc, mỗi bước hiển thị trong phần xem trước.
- Đề xuất **Sinh Cơ Diệp** hồi 12 sinh lực tối đa đến trần và tiêu hao lá khi dùng. Dược thảo hồi giữa màn, còn lá để dành cho lúc nước sôi lửa bỏng trong trận. Tính lượng hồi và đòn đáp trả trên cùng phần xem trước.
- Cảnh giới mở cùng chương, tư chất quyết định dung lượng chân nguyên. Sau khi hồi sinh, trang bị, vật phẩm và hiệu ứng của lượt cũ được đặt lại. Bỏ qua Khai Khiếu lấy lại hồ sơ nhân vật và tư chất trước đó.
- Nền, ô chặn, đòn trùm và thưởng đã chọn cần khôi phục đúng sau khi tải lại. Mỗi bản đồ phải có đường đi hợp lệ và ít nhất một cách tránh đòn được báo. Kiểm Đinh đẳng với 0 chân nguyên tại màn hai, cả khi chọn hồi phục lẫn lấy Cổ.

Các con số, cách nhận đồ và hành vi địch ở trên là thiết kế game đề xuất. Trong truyện, Ngọc Bì là Cổ phòng ngự Nhất chuyển, Bạch Ngọc và Nguyệt Mang là Nhị chuyển, còn Sinh Cơ Diệp là lá trị thương do Cửu Diệp Sinh Cơ Thảo sinh ra. Địa Thính Nhục Nhĩ Thảo dùng để nghe động tĩnh. [Chương 98](https://truyenfull.live/co-chan-nhan/chuong-98/) · [Chương 102](https://vietnamthuquan.eu/TacPham/co-chan-nhan-25730/chuong-102) · [Chương 130](https://truyenfull.live/co-chan-nhan/chuong-130/)

## Thứ tự triển khai

1. Luyện trận dùng cùng bộ luật với Vượt Thanh Mao và tách bản lưu. Đây là nơi thử từng Cổ và cách đánh trùm.
2. Luyện trận và phần thưởng đã dùng chung luật Ngọc Bì Cổ và Sinh Cơ Diệp. Gemini phụ trách nguồn chỉnh sửa, icon, atlas và clip duyệt hai hiệu ứng trên nhánh riêng. Bản Godot hiện dùng hiệu ứng dựng bằng mã.
3. Ba bố cục vách che, đòn lao theo hàng và điểm nghỉ đã vào luật lưu v3. Gemini phụ trách viền vách và hình báo đòn ở đúng cỡ chơi. Các lượt đang chơi ở v1/v2 giữ luật đã dùng khi bắt đầu.
4. Hai đòn và nhịp hồi của Cuồng Điện Lang đã có trong lượt chính và Luyện trận. Kết quả dò đường thắng là mốc kiểm bố cục. Duyệt nhịp di chuyển, báo đòn và hiệu ứng trong Godot trước khi chốt cân bằng.
5. Chọn bộ Nhị chuyển sau khi thắng Cuồng Điện Lang. Chín cặp dùng được trong lượt mới và Luyện trận. Gemini làm atlas Nguyệt Mang và Bạch Ngọc trên nhánh asset riêng.
6. Nối Bãi Đá Suối Sấm, cho đổi bộ giữa hai màn và thêm hệ Tửu. Lượt v4 tiếp tục giữ luật cũ ở Sườn đá Mù Sương và nhận luật mới ở Suối Sấm. Gemini phụ trách atlas Tửu Trùng, Tứ Vị Tửu Trùng và ô nước nông có dấu nhiễm điện.

## Bộ Cổ ở Nhị chuyển

Mỗi màn thử cấp một Cổ Nhị chuyển và một Cổ Nhất chuyển để lắp thành cặp. Giá trị sinh lực, chân nguyên và số lá chuyển sang được hiển thị trước khi xác nhận. Có thể chọn lại cặp trước trận Suối Sấm. Luyện trận cho đổi cặp và chơi lại với cả ba hệ.

| Hệ | Cặp cùng hệ | Cách đánh trong demo |
| --- | --- | --- |
| Nguyệt | Nguyệt Quang Cổ + Nguyệt Mang Cổ | Nguyệt Quang đặt Nguyệt Ấn. Nguyệt Mang có tầm 6 ô, tốn 3 chân nguyên, gây 30 sát thương và thêm 12 khi tiêu ấn. Chỉ một ấn bám trên địch và giữ đến khi bị tiêu hoặc trận kết thúc. |
| Hộ thể | Ngọc Bì Cổ + Bạch Ngọc Cổ | Luật v5 cho Bạch Ngọc chặn 11 sát thương của đòn kế tiếp trong ba lượt, tốn 2 chân nguyên. Thay lớp Ngọc Bì đang hoạt động tăng sức chặn lên 15 và chỉ tốn 1 chân nguyên. Lớp Bạch Ngọc của bộ này chặn được sát thương thì cú Tay không kế tiếp được cộng 10 sát thương. |
| Tửu | Tửu Trùng + Tứ Vị Tửu Trùng | Tửu Trùng hồi tối đa 2 chân nguyên, dùng được hai lần mỗi trận. Tứ Vị tốn 2 chân nguyên để cộng 12 sát thương cho cú Tay không kế tiếp. Dùng Tửu Trùng trước khi kích Tứ Vị cho hai cú được cường hóa. |
| Phối hệ | Sáu cặp khác hệ | Dùng tác dụng cơ bản của từng Cổ. Ví dụ dùng Tửu Trùng để nạp chân nguyên cho Nguyệt Mang hoặc Bạch Ngọc. |

Sinh Cơ Diệp là vật phẩm trị thương dùng chung với cả ba hệ. Màn thử cấp sẵn cặp Cổ. Khi làm hệ thống hợp luyện, chương 98 là cơ sở cho hai bí phương: Nguyệt Quang và hai Tiểu Quang tạo Nguyệt Mang, Bạch Thỉ và Ngọc Bì tạo Bạch Ngọc. Chương 100 mô tả lớp phòng hộ trắng mỏng của Bạch Ngọc mạnh hơn Ngọc Bì. Hiệu ứng bộ, Phản đòn và các con số trong bảng là luật thiết kế của demo. [Chương 98](https://truyenhoan.com/co-chan-nhan/chuong-98.html) · [Chương 100](https://tangthuvienhd.com/truyen/co-chan-nhan/chuong-100.html)

Chương 225 mô tả Tửu Trùng tinh luyện chân nguyên của cổ sư Nhất chuyển. Chương 121 mô tả Tứ Vị Tửu Trùng tinh luyện chân nguyên Nhị chuyển. Tên hệ Tửu, cách hồi chân nguyên theo lượt và cách cường hóa Tay không là thiết kế riêng của demo. [Chương 121](https://tangthuvienhd.com/truyen/co-chan-nhan/chuong-121.html) · [Chương 225](https://truyenfull.live/co-chan-nhan/chuong-225/)

Kiểm thử v5 đi hết hai màn Nhị chuyển với 108 tổ hợp gồm chín bộ, bốn bậc tư chất và ba cặp bố cục. Khi phát lại đúng 12 chuỗi hành động có dùng Bạch Ngọc của v4 trên luật v5, bộ Hộ thể thắng với thêm 3–6 sinh lực ở Sườn đá Mù Sương. Một đường thắng thử của bộ Hộ thể ở Suối Sấm còn 5 sinh lực.

Khi thêm hệ mới, chuẩn bị ít nhất hai Cổ có vai trò bổ sung và một lựa chọn phối hệ. Chốt tương tác trong Luyện trận trước khi đưa cả bộ vào chiến lợi phẩm. Địa Thính Nhục Nhĩ Thảo phù hợp một nhánh do thám khi đã có màn phục kích và đường đi để người chơi tận dụng.

<details>
<summary>Kế hoạch của bản thử thú triều trước đây</summary>

Tài liệu này ghi kế hoạch của bản thử thú triều. Hướng web hiện hành là [roguelike theo lượt](../README.md), dùng lại Đại điển Khai Khiếu làm phần mở đầu.

Bản hiện tại chơi được từ Đại điển Khai Khiếu qua cảnh Cuồng Điện Lang đánh lũy, báo tin ở hậu trại và theo đội trưởng qua đường rừng đến cuộc chạm trán một con sói. Bản đồ 42 × 26 ô đã có tìm đường, đi bộ, chạy, lối giữa cầu thang và giao chiến thời gian thực. Trận Đấu nhanh ở Thềm Hứng Mây giữ chế độ đánh theo lượt.

## Mạch của bản demo

Chọn giới tính và Cổ nhất chuyển → Khai Khiếu, hiện tư chất → Sơn Trại trong thú triều → theo đồng đội qua lối hông → cùng NPC đánh đợt sói đầu → Sói Vương áp sát → rút lui, đồng đội đỡ đòn → rơi xuống vách núi → thử một tương tác truyền thừa → cảnh kết.

Kịch bản mở đầu nối lễ Khai Khiếu sang thú triều bằng một đoạn chuyển thời gian ngắn. Tĩnh Nghi đưa người chơi qua bài học phòng thủ, rồi sai đi gọi viện binh khi Cuồng Điện Lang xuất hiện. Đội trưởng phái hai cổ sư lên lũy và dẫn người chơi qua cổng đông bên hông tới điểm tập kết. Kịch bản tiếp theo đặt đội viện trợ đang phá vòng vây trong rừng. Một Điện Lang tách đàn phát hiện người chơi và mở trận hướng dẫn theo lượt. Sau trận, người chơi tới nói chuyện với đội. [Brief Sơn Trại trong thú triều](brief-co-nguyet-son-trai.md) · [Bố cục rừng để duyệt](forest-ambush/README.md)

## Thứ tự làm

| Mốc | Phần làm | Điều kiện hoàn thành |
| --- | --- | --- |
| 1 | Dựng luồng dẫn truyện từ màn chọn nhân vật đến trận sói hiện có bằng các cảnh ngắn. Nối giới tính, Cổ đã chọn và tư chất vào trạng thái người chơi. | Chơi được từ màn mở đầu đến lượt đầu của trận. Nút chơi lại đưa về đầu, còn thử lại trận giữ lựa chọn ban đầu. |
| 2 | Dựng Sơn Trại lúc thú triều từ tileset đang có. Thêm dấu hiệu giao chiến trên lũy, đồng đội ở ngã rẽ và lối hông ra rừng. | Người chơi nhìn ra đường cần đi, có thể khám phá sân và lũy, đến điểm hẹn bằng phím hoặc cảm ứng. |
| 3 | Thấy đội viện trợ phá vây. Một Điện Lang phát hiện người chơi, mở bài hướng dẫn đánh theo lượt. | Cả hai skin chơi được từ lúc thấy đội tới sau trận và tương tác với đội viện trợ. Hướng dẫn bám hành động và ý định thật của đối thủ. |
| 4 | Sói Vương xuất hiện sau đợt đầu. Mục tiêu đổi sang rút lui và hiện ô thoát. Tại đó, đồng đội đỡ đòn rồi nhân vật rơi xuống vách núi. | Người chơi nhìn thấy mục tiêu mới và tự điều khiển tới lối thoát. Cảnh rơi phát một lần rồi chuyển vị trí sang khu truyền thừa. |
| 5 | Dựng khoang truyền thừa và một tương tác có kết quả rõ ràng. Phát cảnh kết rồi hiện lựa chọn chơi lại. | Có thể hoàn thành toàn bộ demo từ lần vào đầu tiên đến cảnh kết bằng bàn phím hoặc cảm ứng. |

## Việc cụ thể đầu tiên

- Map Đại điển Khai Khiếu được dựng trước dưới dạng màn chơi riêng, với vườn Nguyệt Lan, áp lực nguyên khí và tư chất tính theo độ sâu. [Luật và nguồn truyện](dai-dien-khai-khieu.md)
- Phác ba màn theo thứ tự **Chọn nhân vật → Chọn Cổ nhất chuyển → Khai Khiếu**. Hai giới tính hiển thị cùng một bộ thông tin. Mẫu nam dùng Huyền bào, mẫu nữ lấy từ bộ đã duyệt trước khi nối vào game.
- Nối kết quả Đại điển vào hồ sơ nhân vật và hiện tác dụng cụ thể trên thanh chân nguyên. Chốt danh sách Cổ nhất chuyển từ dữ liệu dự án trước khi gắn chỉ số.
- Nối cảnh Khai Khiếu với điểm xuất phát trên map hiện có. Chèn báo động và mục tiêu gặp đồng đội làm tín hiệu chuyển cảnh.
- Thử hai giới tính, mỗi Cổ khởi đầu, chơi lại và thử lại trận trên máy tính và điện thoại trước khi dựng các cảnh tiếp theo.

</details>
