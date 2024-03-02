var timer = null

function start(){
    var time = new Date()
    var hours = time.getHours()
    var minutes = time.getMinutes()
    minutes=((minutes < 10) ? "0" : "") + minutes
    var seconds = time.getSeconds()
    seconds=((seconds < 10) ? "0" : "") + seconds
    var clock = hours + ":" + minutes + ":" + seconds
    document.forms[0].display.value = clock
    timer = setTimeout("start()",1000)
}
