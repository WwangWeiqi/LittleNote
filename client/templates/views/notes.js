import {Template} from 'meteor/templating';
import {Notes} from '../../../imports/api/notes/notes.js';
import {Accounts} from '../../../imports/api/accounts/accounts.js';
import {dateFormat, getPrice} from '../../utils.js';
import MoacConnect from '../../moacconnect.js';
import { type } from 'os';

var myContract;

var notesLoaded = false;
var accountsLoaded = false;

Meteor.subscribe('notes', function(){ notesLoaded = true; });
Meteor.subscribe('accounts', function(){ accountsLoaded = true; });

Meteor.startup(function() {
    MoacConnect.InitChain3();
});

Template.notesbody.helpers({
    // notes:[
    //     {
    //         notelink: "https://google.com"
    //         ,notetext: "This is the center of the Universe."
    //         ,notetime: "2018/10/14 15:00 UTC"
    //         ,noteuser: "C Ronaldo"
    //         ,noteaccount: "0xbc84fbf220e0301ae032d315eccd00c29838687d"
    //         ,notelat: "45.0703"
    //         ,notelng: "7.6869"
    //         ,isForSell: false
    //         ,noteforsellinfo: "Price: 1.25MC"
    //         ,noteid: 111
    //     }
    //     ,{
    //         notelink: "https://google.com"
    //         ,notetext: "This is the center of the Catalonia."
    //         ,notetime: "2018/10/14 15:00 UTC"
    //         ,noteuser: "L Messi"
    //         ,noteaccount: "0x2a24ed9b55112201cb46a55defac682099885058"
    //         ,notelat: "41.3851"
    //         ,notelng: "2.1734"
    //         ,isForSell: true
    //         ,noteforsellinfo: "Price: 1.36MC"
    //         ,noteid: 12
    //     }
    // ],
    'notes': function() {
        // var topLeft = {latlng: {lng: -120, lat: 60}};
        // var bottomRight = {latlng: {lng: -110, lat: 50}};
        // var query = Notes.findByBoundary(topLeft, bottomRight);
        template = Template.instance();
        
        var myNotesSort = TemplateVar.get(template, 'myNotesSort');
        var sortOption = {};
        if (typeof(myNotesSort) === 'undefined' || myNotesSort === 'updatedAt')
        {
            sortOption = {sort: {updatedAt: -1}};
        }

        var query = Notes.find({}, sortOption);
        var notes = query.fetch();
        notes.forEach(function(n) {
            var q = {address: n.address};
            var account = Accounts.find(q).fetch();
            n.displayDate = dateFormat(n.updatedAt);
            if (account.length > 0) {
                n.name = account[0].name;
            }
            console.log("getnotes from views");
            n.price = getPrice(n.grid10, true)
            if (n.forSell) {
                n.forSellInfo = n.price;
            }
        });

        if (typeof(myNotesSort) !== 'undefined' && myNotesSort === 'price')
        {
            notes = notes.sort(function(a, b){
                return b.price-a.price;
            });
        }

        console.log('getNotes 1', notes);
        return notes;
    },
    'isMicroMessage': function () {
        var ua = window.navigator.userAgent.toLowerCase();
        console.log(ua);
        if(ua.match(/MicroMessenger/i) == 'micromessenger'){
            return true;
        }
        else {
            return false;
        }
    },
    'isAndroid': function () {
        var ua = window.navigator.userAgent.toLowerCase();
        console.log(ua);
        if(ua.match(/android/i) == 'android'){
            return true;
        }
        else {
            return false;
        }
    },
    'isApple': function () {
        var ua = window.navigator.userAgent.toLowerCase();
        console.log(ua);
        if(ua.match(/iphone/i) == 'iphone'){
            return true;
        }
        else {
            return false;
        }
    },
    'getNotes': function() {
        var query = Notes.find({});
        var notes = query.fetch();
        console.log('getNotes 2', notes);
        return notes;
    },
});

Template.notesbody.onCreated(function(){
    var template = Template.instance();
    TemplateVar.set(template, 'latestViewClick', true);
    TemplateVar.set(template, 'hottestViewClick', false);
});

Template.notesbody.events({
    'click .latestView': function(e){
        var template = Template.instance();
        TemplateVar.set(template, 'myNotesSort', 'updatedAt');
        TemplateVar.set(template, 'latestViewClick', true);
        TemplateVar.set(template, 'hottestViewClick', false);
    },
    'click .hottestView': function(e){
        var template = Template.instance();

        TemplateVar.set(template, 'myNotesSort', 'price');
        TemplateVar.set(template, 'latestViewClick', false);
        TemplateVar.set(template, 'hottestViewClick', true);
    },
});

Template.note.helpers({
    'localTime': function(inputDate){
        var nd = new Date(inputDate.replace(/-/g, "/"));
        return nd.toLocaleDateString() +' '+ nd.toLocaleTimeString();
    },
    'jackpot': function(gameNumber) {

        if (!contractInstance && (typeof chain3 !== 'undefined')) {
            contractInstance = chain3.mc.contract(contractAbi).at(contractAddress);
        }

        if (contractInstance) {
            var match = contractInstance.matches(gameNumber);
            var index = 8;
            return Math.floor(match[index]/1000000000000000000 + 0.5)+ ' WCT';
        } else {
            return "";
        }
    },
    'betTokenBalances': function() {

    },
    'isShowButton': function(inputTime){
        var currentTimeStamp = new Date().getTime();
        var gameTimeStamp = new Date(inputTime).getTime();

        if(currentTimeStamp >= gameTimeStamp) {
            return false;
        } 
        return true;
    },
    'isShowDraw': function(gameNumber){
        if(gameNumber>48){
            return false;
        }
        return true;
    }
});

Template.note.events({
    'click .forsell': function(e) {
        myContract = $(e.target).data('contract');
        // myContract = e.target.dataset.contract;
        Modal.show('qrModal');
    },
    'click .notecoordinates': function(e) {
        var lat = parseFloat($(e.target).data('lat'));
        var lng = parseFloat($(e.target).data('lng'));
        var noteid = $(e.target).data('noteid');
        // console.log('click .notecoordinates', lat, lng);
        var zoomFlag = true;
        Template.map.moveto(lat, lng, noteid, zoomFlag);
    },
    'click .notetext': function(e) {
        var lat = parseFloat($(e.target).data('lat'));
        var lng = parseFloat($(e.target).data('lng'));
        var noteid = $(e.target).data('noteid');
        // console.log('click .notecoordinates', lat, lng);
        var zoomFlag = true;
        Template.map.moveto(lat, lng, noteid, zoomFlag);
    },
    // ,
    // 'click .notevalue': function(e) {
    //     var lat = parseFloat($(e.target).data('lat'));
    //     var lng = parseFloat($(e.target).data('lng'));
    //     var noteid = $(e.target).data('noteid');
    //     console.log('click .notecontainer', lat, lng, noteid);
    //     Template.map.move(lat, lng, noteid);
    // }

 });

Template.qrModal.helpers({
    contract: function(){
        return myContract;
    },
    tx: function(){
        return "moac:"+myContract+"?amount=1.000000&token=MOAC";
    },
    clipboard: function(){
        var clipboard = new Clipboard('.btn');
    }
});

Template.map.onRendered(function (){
    $('.marquee').marquee({
        //speed in milliseconds of the marquee
        duration: 15000,
        //gap in pixels between the tickers
        gap: 50,
        //time in milliseconds before the marquee will start animating
        delayBeforeStart: 0,
        //'left' or 'right'
        direction: 'left',
        //true or false - should the marquee be duplicated to show an effect of continues flow
        duplicated: true
      });
});

Template.map.helpers({
    'headline': function(){
        try
        {
            MoacConnect.GetJackpot(function(e,c) {
                if(!e)
                {
                    return c.toString();
                }
                else
                {
                    return TAPi18n.__("app.NoJackpotInfo");
                }
            })
        }
        catch(e)
        {
            return TAPi18n.__("app.NoJackpotInfo");
        }
    },
});