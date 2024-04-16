---
title: "BYPASS FREERASP MOBILE PROTECTION"
layout: single
last_modified_at: 08-01-2024T16:08:30
categories:
  - Blog
tags:
  - Security Mobile
  - Hacking Mobile
  - Pentest Mobile

toc: true
toc_label: "Content Security"
toc_sticky: true
---

![freeRasp](https://raw.githubusercontent.com/talsec/Free-RASP-Community/master/visuals/freeRASP.png)

> `freeRASP` for Flutter is a mobile in-app protection and security monitoring SDK. It aims to cover the main aspects of RASP (Runtime App Self Protection) and application shielding.
> The `freeRASP` is available for Flutter, Android, and iOS developers. We encourage community contributions, investigations of attack cases, joint data research, and other activities aiming to make better app security and app safety for end-users.

`freeRASP` SDK is designed to combat

- Reverse engineering attempts
- Re-publishing or tampering with the apps
- Running application in a compromised OS environment
- Malware, fraudsters, and cybercriminal activities

Key features are the detection and prevention of

- Root/Jailbreak (e.g., unc0ver, check1rain)
- Hooking framework (e.g., Frida, Shadow)
- Untrusted installation method
- App/Device (un)binding

Trên thị trường hiện nay, `freeRASP` được coi là một trong những thư viện phổ biến và an toàn đối với các ứng dụng di động. Do các tính năng được giới thiệu cũng như cách triển khai của nó khá là dễ dàng đối với các lập trình viên ứng dụng di động. Vậy liệu rằng nó có thực sự an toàn hay không.

## Luồng hoạt động của freeRASP

Do freeRASP là một thư viện mã nguồn mở nên ta hoàn toàn có thể xem source của nó được công khai trên [Github](https://github.com/talsec/Free-RASP-Flutter). Dựa vào source code ta có thể phân tích được luồng hoạt động của thư viện này. Đầu tiên ta cần xem tổng quan chương trình này sẽ có các hành động kiểm tra gì.
<!-- Syntax zoom -->
[![source_github1](/assets/images/report/freeRasp/source_github1.png){:class="img-responsive"}](/assets/images/report/freeRasp/source_github1.png)

Thử tìm kiếm từ `Root` bên trong source thì thấy có file `PluginThreatHandler.kt` có một hàm tên là `onRootDetected()`. Bên cạnh hàm này ta còn thấy các hàm khác có vẻ như là dùng để thực hiện check các biện pháp bảo mật khác như Emulator hay Debugger,... Bên trong các hàm kiểm tra đó ta có thể thấy rằng nó gọi đến hàm `notify()` và truyền vào đối tượng threat được xác định. Hàm `notify()` này có nhiệm vụ lắng nghe và gọi tới hàm `threatDetected` nếu giá trị listener khác `null`. Nếu `listener` là `null` thì toàn bộ biểu thức này sẽ trả về `null`. `?:` toán tử Elvis này thực hiện kiểm tra giá trị có null hay không. Nếu giá trị bên trái toán tử (`listener?.threatDetected(threat)`) khác thì nó sẽ trả về giá trị đó; ngược lại nó sẽ trả về giá trị bên phải của toán tử (`detectedThreats.add(threat)`). Có thể hình dung đoạn code rõ ràng sẽ trông như sau:

```
if(listener !== null) {
    // gọi đối phương thức threatDetected(threat) trên đối tượng = null
}
else {
    listener?.threatDetected(threat)
} <=> listener?.

------------------------------------

if(listener?.threatDetected(threat) !== null) {
	if(listener !== null) {
            // gọi đối phương thức threatDetected(threat) trên đối tượng listener
	}
	else {
	    listener?.threatDetected(threat) = null
	}
}
else {
	(detectedThreats.add(threat))
}
```

Dựa vào hàm `threatDetected()` ta lại tiếp tục trace tới hàm đó bên trong source code.

[![source_github2](/assets/images/report/freeRasp/source_github1.png){:class="img-responsive"}](/assets/images/report/freeRasp/source_github1.png)

Ta thấy hàm `threatDetected()` được định nghĩa trong file `TalsecThreatHandler.kt` thực hiện kiểm tra xem nếu hàm `eventSink?.success(threatType.value)` khác `null` thì sẽ thực hiện gọi hàm đó.
Đến đây thì ta có thể hiểu được follow cơ bản của việc kiểm tra bên trong thư viện `freeRASP` rồi.
Tiếp theo ta cần xem xem bên trong ứng dụng thực tế thì sẽ như thế nào.

## Reverse Engineering Android Apps để Bypass Root Detection

Sử dụng `jadx-gui` để thực hiện dịch ngược file apk. Trong một số trường hợp do ứng dụng thường đã bị `obfuscated` nên ta có thể sử dụng `dex2jar` để biên dịch thành file jar trước rồi mới sử dụng `jadx-gui` để đọc mã code. Tuy nhiên, trong trường hợp này thì ta không cần.
Đầu tiên để xác định được hàm check root ở đâu trong ứng dụng ta cần tìm tới hàm main mà ứng dụng sẽ thực hiện gọi khi khởi động.

[![reverse1](/assets/images/report/freeRasp/reverse1.png){:class="img-responsive"}](/assets/images/report/freeRasp/reverse1.png)

Tiếp đó thử xem các file được import trong MainActivity xem có gì thú vị không.

[![reverse2](/assets/images/report/freeRasp/reverse2.png){:class="img-responsive"}](/assets/images/report/freeRasp/reverse2.png)

Có vẻ như không có thứ chúng ta cần tìm vậy quay trở lại source code và sử dụng tên các file để tìm xem được không. Jadx-gui có hỗ trợ việc tìm kiếm toàn cục (Global search) bằng tổ hợp phím `Ctrl+Shift+F`.

[![reverse3](/assets/images/report/freeRasp/reverse3.png){:class="img-responsive"}](/assets/images/report/freeRasp/reverse3.png)

Ta thấy từ khoá `FreeraspPlugin` có file nằm trong folder `com.aheaditec.freerasp.FreeraspPlugin` chứa nó. Vậy thử mở folder đó ra và tìm các file liên quan xem có gì không.

[![reverse4](/assets/images/report/freeRasp/reverse4.png){:class="img-responsive"}](/assets/images/report/freeRasp/reverse4.png)

Có lẽ vẫn chưa có gì để khai thác tiếp tục xem các file được import vào `FreeraspPlugin` xem sao.
Ta thấy có file `TalsecThreatHandler` rất giống file `TalsecThreatHandler.kt` trong source code trước đó và `p4` có lẽ là folder chứa các file thực hiện logic kiểm tra mà chúng ta cần tìm.
Thử mở folder p4 ra xem

[![reverse5](/assets/images/report/freeRasp/reverse5.png){:class="img-responsive"}](/assets/images/report/freeRasp/reverse5.png)

Ta có thể thấy đây là hai file mà chúng ta đã phân tích trước đó. Vậy hãy thử xem source của nó xem có giống với code mà chúng ta đã xem không.

[![reverse6](/assets/images/report/freeRasp/reverse6.png){:class="img-responsive"}](/assets/images/report/freeRasp/reverse6.png)

Dựa vào các tham số của hàm ta có thể xác định được hàm này là hàm `threatDetected()` bên trong file `TalsecThreatHandler`.

[![reverse7](/assets/images/report/freeRasp/reverse7.png){:class="img-responsive"}](/assets/images/report/freeRasp/reverse7.png)

Đây chính là đoạn kiểm tra threat tương ứng với đoạn kiểm tra trong source code tuy nhiên tên hàm đã bị `obfuscated`. Kể cả hàm notify, tuy nhiên jadx-gui có một chức năng rename (short_cut: `n`) cũng như là comment(short_cut: `;`) giúp việc phân tích của các reverse engineer dễ dàng hơn. Như ta có thể thấy phía trên hàm notify có một comment với nội dung `renamed from: l` tức là tên trước đó của nó là `l`. Ngoài ra ta cũng có thể sử dụng tính năng `cross-preference` để trace ra nơi nào gọi hàm này bằng short-cut `x`.

[![reverse8](/assets/images/report/freeRasp/reverse8.png){:class="img-responsive"}](/assets/images/report/freeRasp/reverse8.png)

Ví dụ như việc hàm a này được gọi bởi một hàm khác tên là `onReceive`.

[![reverse9](/assets/images/report/freeRasp/reverse9.png){:class="img-responsive"}](/assets/images/report/freeRasp/reverse9.png)

Nhìn hàm này ta có thể đoán được việc chúng sử dụng intent để trao đổi dữ liệu giữa các event. Vậy nếu intent này trả về null thì có vẻ như ta sẽ bypass được các switch case này.

## Thực hiện bypass root detection với frida

Script thực hiện việc hook vào class `s4.e` và overload lại hàm `onReceive` trong class này để implementation sau đó sửa đổi giá trị intent của nó về `null` trước khi gọi hàm này.

[![script1](/assets/images/report/freeRasp/script1.png){:class="img-responsive"}](/assets/images/report/freeRasp/script1.png)

Thực hiện chạy script trên ta sẽ có kết quả như sau

[![result1](/assets/images/report/freeRasp/result1.png){:class="img-responsive"}](/assets/images/report/freeRasp/result1.png)
