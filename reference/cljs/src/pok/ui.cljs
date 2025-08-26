(ns pok.ui
  "Minimal UI Components for AP Statistics PoK Blockchain
   Focus on question display with profile/stats modals
   Responsive design for desktop/mobile without keyboard dependencies"
  (:require [reagent.core :as r]
            [re-frame.core :as rf]
            [cljs.test :refer-macros [deftest is testing run-tests]]
            [pok.renderer :as renderer]
            [pok.curriculum :as curriculum]
            [pok.state :as state]
            [pok.qr :as qr]
            [pok.flow :as flow]))