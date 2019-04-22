//
// Copyright 2016 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
import UIKit
import AVFoundation
import googleapis

let SAMPLE_RATE = 16000

class ViewController : UIViewController, AudioControllerDelegate {
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var imageView: UIImageView!
    var audioData: NSMutableData!

  override func viewDidLoad() {
    super.viewDidLoad()
    textView.dataDetectorTypes = UIDataDetectorTypes.all
    AudioController.sharedInstance.delegate = self
  }

  @IBAction func recordAudio(_ sender: NSObject) {
    let audioSession = AVAudioSession.sharedInstance()
    do {
        try audioSession.setCategory(AVAudioSession.Category.record)
    } catch {

    }
    audioData = NSMutableData()
    _ = AudioController.sharedInstance.prepare(specifiedSampleRate: SAMPLE_RATE)
    SpeechRecognitionService.sharedInstance.sampleRate = SAMPLE_RATE
    _ = AudioController.sharedInstance.start()
  }

  @IBAction func stopAudio(_ sender: NSObject) {
    _ = AudioController.sharedInstance.stop()
    SpeechRecognitionService.sharedInstance.stopStreaming()
  }

  func processSampleData(_ data: Data) -> Void {
    audioData.append(data)

    // We recommend sending samples in 100ms chunks
    let chunkSize : Int /* bytes/chunk */ = Int(0.1 /* seconds/chunk */
      * Double(SAMPLE_RATE) /* samples/second */
      * 2 /* bytes/sample */);

    if (audioData.length > chunkSize) {
      SpeechRecognitionService.sharedInstance.streamAudioData(audioData,
                                                              completion:
        { [weak self] (response, error) in
            guard let strongSelf = self else {
                return
            }
            
            if let error = error {
                strongSelf.textView.text = error.localizedDescription
            } else if let response = response {
                var finished = false
                print(response)
                for result in response.resultsArray! {
                    if let result = result as? StreamingRecognitionResult {
                        if result.isFinal {
                            finished = true
                            print("it finished")
                        }
                        else{
                            print("duration")
                        }
                    }
                }
                strongSelf.textView.text = response.description
                if finished {
                    strongSelf.stopAudio(strongSelf)
                    
                    let url = URL(string: "https://wordcloudservice.p.rapidapi.com/generate_wc")
                    var request = URLRequest(url: url!)
                    
                    // POSTを指定
                    request.httpMethod = "POST"
                    // json形式でデータを送信
                    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                    // WordCloudAPIの認証情報
                    request.addValue("wordcloudservice.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
                    request.addValue("03b9d85ae9msh9d564ccdb598d71p139399jsna507c8dd9eb4", forHTTPHeaderField: "X-RapidAPI-Key")
                    // POSTするデータを構造体で定義
                    struct Record:Codable {
                        let textblock:String
                    }
                    // 以下HTTP POST
                    let record = Record(textblock:"Lorem ipsum dolor sit amet")
                    let encoder = JSONEncoder()
                    do {
                        let data = try encoder.encode(record)
                        let jsonstr:String = String(data: data, encoding: .utf8)!
                        request.httpBody = jsonstr.data(using: .utf8)
                        print(jsonstr)
                    } catch {
                        print(error.localizedDescription)
                    }
                    // 以下HTTP POSTのレスポンス
                    let session = URLSession.shared
                    session.dataTask(with: request) { (data, response, error) in
                        if error == nil, let data = data, let response = response as? HTTPURLResponse {
                            // HTTPヘッダの取得
                            print("Content-Type: \(response.allHeaderFields["Content-Type"] ?? "")")
                            // HTTPステータスコード
                            print("statusCode: \(response.statusCode)")
                            
                            let dic = try! JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String: Any]
                            let imgUrl = dic["url"] as! String
                            print("url \(imgUrl)")
                            
                            // 画像をurlで表示させたいときは以下コメントアウト
//                            strongSelf.textView.text = imgUrl
                            
                            let url = NSURL(string: imgUrl);
                            let imageData = NSData(contentsOf: url! as URL) //もし、画像が存在しない可能性がある場合は、ifで存在チェック
//                            strongSelf.imageView.image = UIImage(data:imageData! as Data)
                        }
                        }.resume()
                }
            }
      })
      self.audioData = NSMutableData()
    }
  }
}
