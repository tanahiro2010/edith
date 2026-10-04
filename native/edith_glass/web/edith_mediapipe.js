// ブラウザ内で MediaPipe Tasks Vision(FaceDetector) を動かし、リアルタイムで顔の枠を出す。
// Flutter(Dart) 側は edithFaceStart/edithFaceBoxes/edithFaceAspect/edithFaceCapture を呼ぶだけ。
// edith-face-tracker.html と同じモデル/技術。往復通信なしなので滑らか（30〜60fps）。
(function () {
  const DETECTOR_MODEL_URL =
    "https://storage.googleapis.com/mediapipe-models/face_detector/blaze_face_short_range/float16/1/blaze_face_short_range.tflite";
  const WASM_URL = "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@1.0.1/wasm";
  const VIDEO_ID = "edith-mp-video";

  let detector = null;
  let video = null;
  let boxes = [];
  let aspect = 1;
  let started = false;
  let currentStream = null;
  let mirror = true; // プレビュー映像を左右反転しているか（枠側も合わせる）

  // 指定の constraints で stream を開き、既存 stream を停止して video に差し替える。
  // フロント/外部カメラは反転表示、バック(environment)は等倍。
  async function openStream(constraints) {
    const stream = await navigator.mediaDevices.getUserMedia({
      video: constraints,
      audio: false,
    });
    if (currentStream) {
      for (const t of currentStream.getTracks()) t.stop();
    }
    currentStream = stream;
    video.srcObject = stream;
    await video.play();

    const settings = stream.getVideoTracks()[0]?.getSettings?.() || {};
    mirror = settings.facingMode !== "environment";
    video.style.transform = mirror ? "scaleX(-1)" : "none";
    if (video.videoWidth > 0 && video.videoHeight > 0) {
      aspect = video.videoWidth / video.videoHeight;
    }
  }

  window.edithFaceStart = async function () {
    if (started) return "ok";
    try {
      const vision = await import(
        "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@1.0.1/vision_bundle.mjs"
      );
      const { FaceDetector, FilesetResolver } = vision;
      const fileset = await FilesetResolver.forVisionTasks(WASM_URL);
      detector = await FaceDetector.createFromOptions(fileset, {
        baseOptions: { modelAssetPath: DETECTOR_MODEL_URL },
        runningMode: "VIDEO",
      });

      video = document.createElement("video");
      video.id = VIDEO_ID;
      video.autoplay = true;
      video.muted = true;
      video.playsInline = true;
      video.style.width = "100%";
      video.style.height = "100%";
      video.style.objectFit = "cover";

      // 初期は自撮り用途で前面カメラを優先。
      await openStream({ facingMode: "user" });
      started = true;

      const loop = () => {
        if (video && video.videoWidth > 0 && video.videoHeight > 0 && detector) {
          aspect = video.videoWidth / video.videoHeight;
          try {
            const res = detector.detectForVideo(video, performance.now());
            boxes = (res.detections || []).map((d) => {
              const b = d.boundingBox;
              return {
                x: b.originX / video.videoWidth,
                y: b.originY / video.videoHeight,
                w: b.width / video.videoWidth,
                h: b.height / video.videoHeight,
                score: d.categories && d.categories[0] ? d.categories[0].score : 0,
              };
            });
          } catch (e) {
            // フレーム未準備など。次フレームで再試行。
          }
        }
        requestAnimationFrame(loop);
      };
      requestAnimationFrame(loop);
      return "ok";
    } catch (e) {
      console.error("edithFaceStart failed:", e);
      return "error:" + (e && e.message ? e.message : e);
    }
  };

  // 利用可能なカメラ（外部USBカメラ含む）を列挙。ラベルは getUserMedia 許可後に埋まる。
  window.edithFaceListCameras = async function () {
    try {
      const devices = await navigator.mediaDevices.enumerateDevices();
      const cams = devices
        .filter((d) => d.kind === "videoinput")
        .map((d) => ({ deviceId: d.deviceId, label: d.label }));
      return JSON.stringify(cams);
    } catch (e) {
      console.error("edithFaceListCameras failed:", e);
      return "[]";
    }
  };

  // 指定 deviceId のカメラに切替（外部カメラ接続・フロント/バック変更の両方に対応）。
  window.edithFaceSwitchCamera = async function (deviceId) {
    if (!started || !video) return "error:not-started";
    try {
      await openStream({ deviceId: { exact: deviceId } });
      return "ok";
    } catch (e) {
      console.error("edithFaceSwitchCamera failed:", e);
      return "error:" + (e && e.message ? e.message : e);
    }
  };

  // 現在のプレビューが左右反転しているか（枠マッピング用）。
  window.edithFaceMirror = function () {
    return mirror;
  };

  window.edithFaceBoxes = function () {
    return JSON.stringify(boxes);
  };
  window.edithFaceAspect = function () {
    return aspect;
  };
  window.edithFaceVideoId = function () {
    return started ? VIDEO_ID : "";
  };
  // Flutter のプラットフォームビューに渡す video 要素そのものを返す。
  window.edithFaceVideoEl = function () {
    return video;
  };
  // 識別用に現在フレームを JPEG(dataURL) で返す。反転前の生ピクセルを使う。
  window.edithFaceCapture = function () {
    if (!video || video.videoWidth === 0) return "";
    const c = document.createElement("canvas");
    c.width = video.videoWidth;
    c.height = video.videoHeight;
    c.getContext("2d").drawImage(video, 0, 0);
    return c.toDataURL("image/jpeg", 0.8);
  };
})();
