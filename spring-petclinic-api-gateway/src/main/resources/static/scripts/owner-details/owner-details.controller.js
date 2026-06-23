'use strict';

angular.module('ownerDetails')
    .controller('OwnerDetailsController', ['$http', '$stateParams', '$state', '$window', function ($http, $stateParams, $state, $window) {
        var self = this;

        $http.get('api/gateway/owners/' + $stateParams.ownerId).then(function (resp) {
            self.owner = resp.data;
        });

        self.deleteOwner = function (ownerId) {
            if (!$window.confirm('Delete this owner and all their data? This cannot be undone.')) return;
            $http.delete('api/customer/owners/' + ownerId).then(function () {
                $state.go('owners');
            });
        };
    }]);
