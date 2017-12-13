// --------------------------------------------------------------------------------------------------------------------
// <copyright company="Microsoft" file="SourceControlServiceTests.cs">
//   Copyright (c) Microsoft Corporation.  All rights reserved.
// </copyright>
// --------------------------------------------------------------------------------------------------------------------

namespace Orchestrator.WebService.UnitTests
{
    using System;
    using System.Collections.Generic;
    using System.Linq;
    using System.Threading;
    using System.Threading.Tasks;

    using Microsoft.VisualStudio.TestTools.UnitTesting;
    using Moq;
    using Orchestrator.Services;
    using Orchestrator.Shared.DataProtector;
    using Orchestrator.Shared.Storage;

    /// <summary>
    /// The source control service tests.
    /// </summary>
    [TestClass]
    public class SourceControlServiceTests
    {
        private const string RepoUrl = "https://github.com/TestAccount/AASCTestProject.git";
        private const SourceControlType SourceControlType = Orchestrator.Shared.Storage.SourceControlType.GitHub;
        private const string RepoBranch = "MyBranch";
        private const string RepoFolderPath = "/MyFolder/";
        private const string RepoSecurityToken = "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz";
        private const bool RepoAutoSync = false;
        private const bool RepoAutoPublish = true;

        private static readonly Guid TestAccountId = Guid.NewGuid();
        private static readonly List<SourceControlData> TestSourceControlStoreData = new List<SourceControlData>();

        [TestInitialize]
        public void TestInitialize()
        {
            SetupSourceControlStoreData();
        }

        [TestCleanup]
        public void TestCleanup()
        {
            CleanupSourceControlStoreData();
        }

        #region PositiveTests
        [TestMethod]
        [TestCategory("CVT")]
        [TestCategory("SourceControl")]
        public void SourceControlServiceReturnsSourceControlsByAccountName()
        {
            // returns all source controls in mock data store
            Func<Guid, SourceControlFilter, string, CancellationToken, Task<PageResult<SourceControlData>>>
                getSourceControlsByAccountNameReturnFunc =
                    (id, filter, contToken, cancToken) =>
                        Task.FromResult(new PageResult<SourceControlData>()
                        {
                            Items = TestSourceControlStoreData,
                        });

            // setup storage provider mock
            var storageProvider = new Mock<IStorageProvider>();
            storageProvider.Setup(provider => provider.SourceControlStore.GetSourceControlsAsync(TestAccountId, It.IsAny<SourceControlFilter>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
                .Returns(getSourceControlsByAccountNameReturnFunc);

            // setup other mocks
            var encrypter = SetupEncrypterMock();
            var jobservice = new Mock<JobService>();
            var service = new SourceControlService(storageProvider.Object, encrypter.Object, jobservice.Object);

            // test
            var result = service.GetSourceControlsByAccountName(TestAccountId, new SourceControlFilter());

            // verify
            Assert.IsNotNull(result);
            Assert.IsNotNull(result.Result);
            var enumerator = TestSourceControlStoreData.GetEnumerator();
            foreach (var resultScd in result.Result.Items)
            {
                enumerator.MoveNext();
                Assert.AreEqual(resultScd, enumerator.Current);
            }
        }

        [TestMethod]
        [TestCategory("CVT")]
        [TestCategory("SourceControl")]
        public void SourceControlServiceReturnsSourceControlBySourceControlName()
        {
            // returns only the source control that matches the filter name expression
            Func<Guid, SourceControlFilter, string, CancellationToken, Task<PageResult<SourceControlData>>>
                getSourceControlByNameReturnFunc = (id, filter, contToken, cancToken) => Task.FromResult(GetSourceControlDataByFilterName(filter));

            // setup storage provider mock
            var storageProvider = new Mock<IStorageProvider>();
            storageProvider.Setup(provider => provider.SourceControlStore.GetSourceControlsAsync(TestAccountId, It.IsAny<SourceControlFilter>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
                .Returns(getSourceControlByNameReturnFunc);

            // setup other mocks
            var encrypter = SetupEncrypterMock();
            var jobservice = new Mock<JobService>();
            var service = new SourceControlService(storageProvider.Object, encrypter.Object, jobservice.Object);

            // test
            var result = service.GetSourceControlByName(TestAccountId, TestSourceControlStoreData.First().Name, false);

            // verify
            Assert.IsNotNull(result);
            Assert.IsNotNull(result.Result);
            Assert.AreEqual(result.Result, TestSourceControlStoreData.First());
        }

        [TestMethod]
        [TestCategory("CVT")]
        [TestCategory("SourceControl")]
        public void SourceControlServiceReturnsSourceControlCount()
        {
            // setup storage provider mock to return count in mock store
            var storageProvider = new Mock<IStorageProvider>();
            storageProvider.Setup(provider => provider.SourceControlStore.GetSourceControlsCountAsync(TestAccountId, CancellationToken.None))
                .Returns(Task.FromResult(TestSourceControlStoreData.Count));

            // setup other mocks
            var encrypter = SetupEncrypterMock();
            var jobservice = new Mock<JobService>();
            var service = new SourceControlService(storageProvider.Object, encrypter.Object, jobservice.Object);

            // test
            var result = service.GetSourceControlsCount(TestAccountId, CancellationToken.None);

            // verify
            Assert.IsNotNull(result);
            Assert.IsNotNull(result.Result);
            Assert.AreEqual(result.Result, TestSourceControlStoreData.Count);
        }

        [TestMethod]
        [TestCategory("CVT")]
        [TestCategory("SourceControl")]
        public void SourceControlServiceCanCreateSourceControl()
        {
            // create new source control
            Func<SourceControlData, CancellationToken, Task<SourceControlData>> createAsyncReturnFunc = (data, canc) =>
            {
                TestSourceControlStoreData.Add(data);
                return Task.FromResult(TestSourceControlStoreData.Last());
            };

            // setup storage provider mock
            var storageProvider = new Mock<IStorageProvider>();
            storageProvider.Setup(provider => provider.SourceControlStore.CreateAsync(It.IsAny<SourceControlData>(), It.IsAny<CancellationToken>())).Returns(createAsyncReturnFunc);

            // returns only the source control that matches the filter name expression
            Func<Guid, SourceControlFilter, string, CancellationToken, Task<PageResult<SourceControlData>>>
                getSourceControlByNameReturnFunc = (id, filter, contToken, cancToken) => Task.FromResult(GetSourceControlDataByFilterName(filter));

            storageProvider.Setup(provider => provider.SourceControlStore.GetSourceControlsAsync(TestAccountId, It.IsAny<SourceControlFilter>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
                .Returns(getSourceControlByNameReturnFunc);

            // setup other mocks
            var encrypter = SetupEncrypterMock();
            var jobservice = new Mock<JobService>();
            var service = new SourceControlService(storageProvider.Object, encrypter.Object, jobservice.Object);

            // test
            var result = service.CreateOrReplaceSourceControl(TestAccountId, GetSourceControlData("CreateTest"), CancellationToken.None);

            // verify
            Assert.IsNotNull(result);
            Assert.IsNotNull(result.Result);
            Assert.AreEqual(result.Result, TestSourceControlStoreData.Last());
        }

        [TestMethod]
        [TestCategory("CVT")]
        [TestCategory("SourceControl")]
        public void SourceControlServiceCanUpdateSourceControl()
        {
            // setup storage provider mock to return count in mock store
            var storageProvider = new Mock<IStorageProvider>();

            // update source control
            Func<SourceControlData, CancellationToken, Task<SourceControlData>> updateAsyncReturnFunc = (data, canc) =>
            {
                var foundData = TestSourceControlStoreData.Find(sc => sc.SourceControlId.Equals(data.SourceControlId));
                foundData = data;
                return Task.FromResult(foundData);
            };
            storageProvider.Setup(provider => provider.SourceControlStore.UpdateAsync(It.IsAny<SourceControlData>(), It.IsAny<CancellationToken>())).Returns(updateAsyncReturnFunc);

            // setup other mocks
            var encrypter = SetupEncrypterMock();
            var jobservice = new Mock<JobService>();
            var service = new SourceControlService(storageProvider.Object, encrypter.Object, jobservice.Object);

            // test
            var firstData = TestSourceControlStoreData.First();
            var prevUrl = firstData.RepoUrl.Clone();

            const string TestUpdateUrlData = "My Updated Url";
            firstData.RepoUrl = TestUpdateUrlData;

            var result = service.UpdateSourceControl(TestAccountId, firstData, CancellationToken.None);
            var newUrl = TestSourceControlStoreData.First().RepoUrl;

            // verify
            Assert.IsNotNull(result);
            Assert.IsNotNull(result.Result);
            Assert.AreNotEqual(prevUrl, TestUpdateUrlData);
            Assert.AreEqual(newUrl, TestUpdateUrlData);
        }

        [TestMethod]
        [TestCategory("CVT")]
        [TestCategory("SourceControl")]
        public void SourceControlServiceCanDeleteSourceControl()
        {
            // setup storage provider mock to return count in mock store
            var storageProvider = new Mock<IStorageProvider>();

            // create new source control
            Func<SourceControlData, CancellationToken, Task<bool>> deleteAsyncReturnFunc = (data, canc) =>
            {
                TestSourceControlStoreData.Remove(data);
                return Task.FromResult(true);
            };
            storageProvider.Setup(provider => provider.SourceControlStore.DeleteAsync(It.IsAny<SourceControlData>(), It.IsAny<CancellationToken>())).Returns(deleteAsyncReturnFunc);

            // returns only the source control that matches the filter name expression
            Func<Guid, SourceControlFilter, string, CancellationToken, Task<PageResult<SourceControlData>>>
                getSourceControlByNameReturnFunc = (id, filter, contToken, cancToken) => Task.FromResult(GetSourceControlDataByFilterName(filter));

            storageProvider.Setup(provider => provider.SourceControlStore.GetSourceControlsAsync(TestAccountId, It.IsAny<SourceControlFilter>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
                .Returns(getSourceControlByNameReturnFunc);

            // setup other mocks
            var encrypter = SetupEncrypterMock();
            var jobservice = new Mock<JobService>();
            var service = new SourceControlService(storageProvider.Object, encrypter.Object, jobservice.Object);

            // test
            var first = TestSourceControlStoreData.First();
            var prevCount = TestSourceControlStoreData.Count;
            var result = service.DeleteSourceControl(TestAccountId, first.Name, CancellationToken.None);

            // verify
            Assert.IsNotNull(result);
            Assert.IsTrue(result.Result);
            Assert.IsNull(TestSourceControlStoreData.Find(sc => sc.Name.Equals(first.Name)));
            Assert.AreEqual(prevCount - 1, TestSourceControlStoreData.Count);
        }
        #endregion

        private static Mock<IEncrypter> SetupEncrypterMock()
        {
            // create encrypter mock that just passes any value through without encrypting it
            var encrypterMock = new Mock<IEncrypter>();
            encrypterMock.Setup(encrypter => encrypter.Encrypt(TestAccountId, It.IsAny<string>())).Returns((Guid id, string token) => token);
            encrypterMock.Setup(encrypter => encrypter.Decrypt(TestAccountId, It.IsAny<string>())).Returns((Guid id, string token) => token);
            return encrypterMock;
        }

        private static PageResult<SourceControlData> GetSourceControlDataByFilterName(SourceControlFilter filter)
        {
            // search store data with filter experession
            var items = TestSourceControlStoreData.Where(filter.Name.Compile());
            return new PageResult<SourceControlData>() { Items = items };
        }

        private static SourceControlData GetSourceControlData(string name)
        {
            return new SourceControlData()
            {
                AccountId = TestAccountId,
                Name = name,
                RepoUrl = RepoUrl,
                SourceControlType = SourceControlType,
                Branch = RepoBranch,
                FolderPath = RepoFolderPath,
                SecurityToken = RepoSecurityToken,
                AutoSync = RepoAutoSync,
            };
        }

        private static void SetupSourceControlStoreData()
        {
            TestSourceControlStoreData.Add(GetSourceControlData(string.Format("SC{0}", 1)));
            TestSourceControlStoreData.Add(GetSourceControlData(string.Format("SC{0}", 2)));
            TestSourceControlStoreData.Add(GetSourceControlData(string.Format("SC{0}", 3)));
            TestSourceControlStoreData.Add(GetSourceControlData(string.Format("SC{0}", 4)));
            TestSourceControlStoreData.Add(GetSourceControlData(string.Format("SC{0}", 5)));
        }

        private static void CleanupSourceControlStoreData()
        {
            TestSourceControlStoreData.Clear();
        }
    }
}