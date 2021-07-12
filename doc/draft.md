## 模組管理

`@plotdb/block` 概念有了以後, 會需要管理

 - 開發 - 不管怎麼開發.
   - 但 plotdb 自己會透過 git + branch + tag 來在 repo 自行管理版本
   - 也有可能會需要將多個 block 置於一 monorepo 中一次做 publish
 - 發布 - 類似 NPM. 指定名稱、版號.
 - 倉儲 - 背後管理機制?
 - 本地端 - 自己跑一個 registrey server ?
   - 可以依靠簡單 http server 機制 serve 檔案
   - 依簡單 http server 的本地發布法
     - 比方說發布到特定目錄
   - 或發布到本地端的中央 registry server


## 命名規則

與 github, npm 對齊. 使用 type, scope + package 的概念:

 - wrap-svg-text
 - @plotdb/form
 - github:loadingio/ldcover


考慮到前端元件可能有群組概念, 但我們又需要依賴現有機制管理, 因此我們在 package name 中利用 `.` 做語意上的分組:

 - form.short-answer
 - @plotdb/config.text
 - github:loadingio/ldcover.error

不一定是功能上 ( 比方說都是圖表 ), 也可能是單純的集合 ( makeweb 的基本區塊集 ), 這種情況下更像是認知上的輔助:

 - @makeweb/basic.hero
 - @makeweb/basic.paragraph
 - @makeweb/basic.gallery
 - @makeweb/basic.footer


其它的選擇各有其問題.

 - 使用子套件 ( @plotdb/form/short-answer )
   - npm 跟 github 都不支援 
   - 若當成 @plotdb/form 下的 short-answer 檔案, 則版本就變成透過 @plotdb/form 管理, 會變得相依性很強, 造成問題.
 - 使用 `@` ( @plotdb/form@short-ansmwer ) 或其它少見字元
   - github 不支援. npm 不明, 但沒見過.
 - 使用 `-` 或 `_` - 名稱太普遍.
 - 使用 org 切分, 如 @plotdb-form/short-answer
   - 語意較差因為實際上並沒有多出一個 @plotdb-form org.


## 內部模組

使用模組的套件, 不一定會全都依賴外部模組, 或者需要將所有模組都獨立管理. 套件本身也可能包含數個模組, 隨著套件本身進版.  
這種情況下, 就可以透過子元件的方式存取模組, 如:

    @plotdb/form@0.0.1/short-answer/


存取這類的模組可以有幾種做法:

 - 完全繞過 registry, 自行管理 block.class
   - 但若需要提供抽換機制, 我們還是得統一 "自行管理" 的方式 - 結果最好還是把機制做在 registry 中.
 - 透過 registry, 但提供路徑概念.
   - 如: `registry: ({name, version, path}) -> "/block/#name/#version/#path/index.html"`
   - 接著就看套件如何將需求對應到 name, version, path 組

透過 registry 的情況下, 如使用 @plotdb/config 時我們會有 text field. 可以想像存取路徑為:

    @plotdb/config@0.0.1/text/index.html

用戶則可能可以客製 text field, 並以下列套件名提供

    @someone/config.text@.0.1
    @someone/config.set@0.0.1/text/index.html

在 @plotdb/config 使用 text 時, 可以直接明確指定模組, 亦或者做轉換. 轉換則由用戶提供方式:

    text -> @someone/config.set@0.0.1/text/index.html

也就是說, 套件提供一組預設轉換函式將 {name, version, type} 轉成 registry 要用的 {name, version, path}, 但這個預設函式可以被用戶客製. 如:

    name: @plotdb/config  -> name: @plotdb/config
    version: 0.0.1        -> version: 0.0.1
    type: text            -> path: text/index.html

客製後:

    name: @plotdb/config  -> name: @someone/config.text
    version: 0.0.1        -> version: 0.0.1
    type: text            -> path: index.html


指涉特定 block 的方式則為:

    {name, version, path}

忽略 path 時, 預設為 `index.html`. ( 或者, 依網頁伺服器定義? )
